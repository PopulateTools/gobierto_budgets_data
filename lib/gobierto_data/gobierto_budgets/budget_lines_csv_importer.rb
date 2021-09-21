# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLinesCsvImporter
      attr_accessor :csv, :output

      def initialize(csv)
        @csv = csv
        @output = []
      end

      def import!
        calculate_acumulated_values
        parse_data
        return 0 if output.blank?

        GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk(body: output)

        return output.length
      end

      private

      def parse_data
        rows.each do |row|
          unless row.valid?
            raise row.errors.map { |attribute, message| "#{attribute}: #{message}" }.join("\n")
          end

          @output.concat(row.data)
        end
      end

      def rows
        @rows ||= csv.map { |row| BudgetLineCsvRow.new(row) }
      end

      def descending_codes_present?
        rows.find(&:parent_code).present?
      end

      def parent_codes_present?
        rows.any? do |r1|
          rows.find { |r2| r2.code == r1.parent_code }
        end
      end

      def calculate_acumulated_values
        return if parent_codes_present? || !descending_codes_present?

        calculations = {}

        rows.each do |row|
          row.code_object.parent_codes.each do |code|
            accumulated_values = calculations[[row.year, code, row.raw_area_name, row.kind, row.functional_code, row.custom_code, row.organization_id]] || {}

            BudgetLineCsvRow::INDEXES_COLUMNS_NAMES_MAPPING.each do |column_name, index|
              accumulated_values[column_name] = (accumulated_values.fetch(column_name, 0) + row.value(index).to_f).round(2)
            end

            calculations[[row.year, code, row.raw_area_name, row.kind, row.functional_code, row.custom_code, row.organization_id]] = accumulated_values
          end
        end

        extra_rows = calculations.map do |(year, code, area_name, kind, functional_code, custom_code, organization_id), values|
          row_values = values.merge(
            "year" => year,
            "code" => code,
            "area" => area_name,
            "kind" => kind,
            "name" => nil,
            "description" => nil,
            "functional_code" => functional_code,
            "custom_code" => custom_code,
            "level" => nil,
            "parent_code" => nil,
            "organization_id" => organization_id,
            "ID" => nil
          )
          BudgetLineCsvRow.new(CSV::Row.new(row_values.keys, row_values.values))
        end

        rows.concat(extra_rows)
      end
    end
  end
end
