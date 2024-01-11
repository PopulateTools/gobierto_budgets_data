# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class Bubbles
      CATEGORIES_LEVELS = [1, 2]

      def self.dump(organization_id)
        bubble_data_builder = new(organization_id)
        bubble_data_builder.build_data_file
        bubble_data_builder.upload_file
      end

      def initialize(organization_id)
        @organization_id = organization_id
        @file_content = []
      end

      attr_reader :organization_id

      def file_name_for(organization_id)
        ["gobierto_budgets", organization_id, "data", "bubbles.json"].join("/")
      end

      def upload_file
        GobiertoBudgetsData::FileUploader.new(adapter: ENV.fetch("GOBIERTO_FILE_UPLOADS_ADAPTER").try(:to_sym) { :s3 }, content: @file_content.to_json,
                                       file_name: file_name_for(organization_id),
                                       content_type: "application/json; charset=utf-8").upload!
      end

      def file_url
        file = GobiertoBudgetsData::FileUploader.new(adapter: ENV.fetch("GOBIERTO_FILE_UPLOADS_ADAPTER").try(:to_sym) { :s3 }, file_name: file_name_for(organization_id))
        file.uploaded_file_exists? && file.call
      end

      def build_data_file
        expense_lines[max_year_level].group_by(&:code).each do |code, lines|
          fill_data_for(code, lines, GobiertoBudgetsData::GobiertoBudgets::EXPENSE, @expense_lines_area_name)
        end

        income_lines[max_year_level].each.group_by(&:code).uniq.each do |code, lines|
          fill_data_for(code, lines, GobiertoBudgetsData::GobiertoBudgets::INCOME)
        end
      end

      def max_year_level
        @max_year_level ||= begin
                              expense_max_years = expense_lines.transform_values { |lines| lines.map(&:year).max }
                              income_max_years = income_lines.transform_values { |lines| lines.map(&:year).max }

                              max_years = expense_max_years.merge(income_max_years) { |_k, v1, v2| [v1, v2].max  }
                              max_year = max_years.values.max

                              max_years.select { |k, v| v == max_year }.keys.max
                            end
      end

      def expense_lines
        @expense_lines ||= begin
                             data_by_area = [
                               GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME,
                               GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
                             ].each_with_object({}) do |area_name, area_data|
                               area_data[area_name] = CATEGORIES_LEVELS.each_with_object({}) do |level, data|
                                 hits = expense_lines_hits(updated_forecast: false, level: level, area_name: area_name)

                                 expense_lines_hits(level: level, area_name: area_name).each do |original_hit|
                                   hits << original_hit if hits.none? { |h| hit_id(h) == hit_id(original_hit) }
                                 end

                                 data[level] = hits
                               end
                             end

                             max_years_by_area = data_by_area.transform_values{|r| r.transform_values { |lines| lines.map(&:year).max }.values.max }
                             max_year = max_years_by_area.values.max
                             @expense_lines_area_name = max_years_by_area.select { |_area_name, year| year == max_year }.keys.first
                             data_by_area[@expense_lines_area_name]
                           end
      end

      def expense_lines_area_name
        @expense_lines_area_name ||= expense_lines && @expense_lines_area_name
      end

      def income_lines
        @income_lines ||= CATEGORIES_LEVELS.each_with_object({}) do |level, data|
          hits = income_lines_hits(updated_forecast: false, level: level)

          income_lines_hits(level: level).each do |original_hit|
            hits << original_hit if hits.none? { |h| hit_id(h) == hit_id(original_hit) }
          end

          data[level] = hits
        end
      end

      def hit_id(hit)
        [hit.year, hit.kind, hit.area_name, hit.code].join("/")
      end

      def expense_lines_hits(options = {})
        level = options[:level] || 2
        updated_forecast = options[:updated_forecast] || false
        area_name = options[:area_name] || GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME

        GobiertoBudgetsData::GobiertoBudgets::BudgetLine.all(
          organization_id: organization_id,
          kind: GobiertoBudgetsData::GobiertoBudgets::EXPENSE,
          area_name: area_name,
          level: level,
          updated_forecast: updated_forecast
        )
      end

      def income_lines_hits(options = {})
        level = options[:level] || 2
        updated_forecast = options[:updated_forecast] || false
        GobiertoBudgetsData::GobiertoBudgets::BudgetLine.all(
          organization_id: organization_id,
          kind: GobiertoBudgetsData::GobiertoBudgets::INCOME,
          area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME,
          level: level,
          updated_forecast: updated_forecast
        )
      end

      def expense_categories(locale, area_name = nil)
        area_name ||= GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
        GobiertoBudgetsData::GobiertoBudgets::Category.all(locale: locale, area_name: area_name, kind: GobiertoBudgetsData::GobiertoBudgets::EXPENSE)
      end

      def income_categories(locale)
        GobiertoBudgetsData::GobiertoBudgets::Category.all(locale: locale, area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME, kind: GobiertoBudgetsData::GobiertoBudgets::INCOME)
      end

      def parent_name(collection, code)
        collection.detect { |c, _| c == code[0..-2] }.last
      rescue StandardError
        "Ingresos patrimoniales" if code.starts_with?("5")
      end

      def localized_name_for(locale, code, kind, area_name = nil)
        if kind == GobiertoBudgetsData::GobiertoBudgets::INCOME
          income_categories(locale)[code]
        else
          expense_categories(locale, area_name)[code]
        end
      end

      def fill_data_for(code, budget_lines, kind, area_name = nil)
        area_name ||= if kind == GobiertoBudgetsData::GobiertoBudgets::EXPENSE
                        GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
                      else
                        GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
                      end
        values = {}
        values_per_inhabitant = {}
        years = budget_lines.map(&:year).sort.reverse
        years.each_with_index do |year, _i|
          if (budget_line = budget_lines.detect { |b| b.year == year })
            values.store(year, budget_line.amount)
            values_per_inhabitant.store(year, budget_line.amount_per_inhabitant)
          else
            values.store(year, 0)
            values_per_inhabitant.store(year, 0)
          end
        end
        pct_diff = {}
        years.each_with_index do |year, i|
          if i < years.length - 1
            previous = values[year - 1].to_f
            current = values[year].to_f
            pct_diff.store(year, (((current - previous) / previous) * 100).round(2))
          else
            pct_diff.store(year, 0)
          end
        end

        data = {
          budget_category: kind == GobiertoBudgetsData::GobiertoBudgets::EXPENSE ? "expense" : "income",
          area_name: area_name,
          id: code.to_s,
          "pct_diff": pct_diff,
          "values": values,
          "values_per_inhabitant": values_per_inhabitant
        }

        data[:level_2_es] = localized_name_for(:es, code, kind, area_name)
        data[:level_2_ca] = localized_name_for(:ca, code, kind, area_name)

        @file_content.push(data)
      end
    end
  end
end
