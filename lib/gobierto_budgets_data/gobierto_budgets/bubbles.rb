# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class Bubbles
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
        expense_lines.group_by(&:code).each do |code, lines|
          fill_data_for(code, lines, GobiertoBudgetsData::GobiertoBudgets::EXPENSE)
        end

        income_lines.each.group_by(&:code).uniq.each do |code, lines|
          fill_data_for(code, lines, GobiertoBudgetsData::GobiertoBudgets::INCOME)
        end
      end

      def expense_lines
        hits = expense_lines_hits(false)

        expense_lines_hits.each do |original_hit|
          hits << original_hit if hits.none? { |h| hit_id(h) == hit_id(original_hit) }
        end

        hits
      end

      def income_lines
        hits = income_lines_hits(false)

        income_lines_hits.each do |original_hit|
          hits << original_hit if hits.none? { |h| hit_id(h) == hit_id(original_hit) }
        end

        hits
      end

      def hit_id(hit)
        [hit.year, hit.kind, hit.area_name, hit.code].join("/")
      end

      def expense_lines_hits(updated_forecast = false)
        GobiertoBudgetsData::GobiertoBudgets::BudgetLine.all(
          organization_id: organization_id,
          kind: GobiertoBudgetsData::GobiertoBudgets::EXPENSE,
          area_name: GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME,
          level: 2,
          updated_forecast: updated_forecast
        )
      end

      def income_lines_hits(updated_forecast = false)
        GobiertoBudgetsData::GobiertoBudgets::BudgetLine.all(
          organization_id: organization_id,
          kind: GobiertoBudgetsData::GobiertoBudgets::INCOME,
          area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME,
          level: 2,
          updated_forecast: updated_forecast
        )
      end

      def expense_categories(locale)
        GobiertoBudgetsData::GobiertoBudgets::Category.all(locale: locale, area_name: GobiertoBudgetsData::GobiertoBudgets::FUNCTIONAL_AREA_NAME, kind: GobiertoBudgetsData::GobiertoBudgets::EXPENSE)
      end

      def income_categories(locale)
        GobiertoBudgetsData::GobiertoBudgets::Category.all(locale: locale, area_name: GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME, kind: GobiertoBudgetsData::GobiertoBudgets::INCOME)
      end

      def parent_name(collection, code)
        collection.detect { |c, _| c == code[0..-2] }.last
      rescue StandardError
        "Ingresos patrimoniales" if code.starts_with?("5")
      end

      def localized_name_for(locale, code, kind)
        if kind == GobiertoBudgetsData::GobiertoBudgets::INCOME
          income_categories(locale)[code]
        else
          expense_categories(locale)[code]
        end
      end

      def fill_data_for(code, budget_lines, kind)
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
          id: code.to_s,
          "pct_diff": pct_diff,
          "values": values,
          "values_per_inhabitant": values_per_inhabitant
        }

        data[:level_2_es] = localized_name_for(:es, code, kind)
        data[:level_2_ca] = localized_name_for(:ca, code, kind)

        @file_content.push(data)
      end
    end
  end
end
