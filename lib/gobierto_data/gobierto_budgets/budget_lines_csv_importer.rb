# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLinesCsvImporter
      attr_accessor :csv, :output

      def initialize(csv)
        @csv = csv
        @output = []
        @accumulated_values = {}
      end

      def import!
        calculate_accumulated_values
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

      def calculate_accumulated_values
        return if parent_codes_present? || !descending_codes_present?

        rows.each do |row|
          base_index = [row.year, row.raw_area_name, row.kind, row.organization_id]
          if row.economic_code_object.present?
            # The values only will be accumulated for the first level of code.
            # To have accumulations on deeper levels iterate over
            # row.code_object.parent_codes
            code = row.code_object.parent_codes.last

            row.economic_code_object.parent_codes.each do |subcode|
              functional_code = row.economic_functional? ? subcode : row.functional_code
              custom_code = row.economic_custom? ? subcode : row.custom_code

              accumulate(base_index + [code, functional_code, custom_code], row)
            end
          else
            row.code_object.parent_codes.each do |code|
              accumulate(base_index + [code, row.functional_code, row.custom_code], row)
            end
          end
        end
        extra_rows = @accumulated_values.map do |(year, area_name, kind, organization_id, code, functional_code, custom_code), values|
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

      def accumulate(index, row)
        values = @accumulated_values[index] || {}

        BudgetLineCsvRow::INDEXES_COLUMNS_NAMES_MAPPING.each do |column_name, index|
          values[column_name] = (values.fetch(column_name, 0) + row.value(index).to_f).round(2)
        end
        @accumulated_values[index] = values
      end
    end
  end
end
