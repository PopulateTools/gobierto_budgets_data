# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLinesCsvImporter
      attr_accessor :csv, :output, :extra_rows

      def initialize(csv)
        @csv = csv
        @output = []
        @accumulated_values = {}
      end

      def import!
        calculate_accumulated_values
        remove_duplicates
        rows.concat(extra_rows)
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

      def last_level?(code)
        rows.find { |r| r.parent_code == code }.blank?
      end

      def descending_codes_present?
        rows.find(&:parent_code).present?
      end

      def custom_codes_tree
        @custom_codes_tree ||= rows.inject({}) do |tree, row|
          next(tree) unless row.custom_parent_code? || row.custom_level?

          tree.update(row.code => calculate_custom_parent_codes(row.code))
        end
      end

      def calculate_custom_parent_codes(code)
        selected_row = rows.find { |r| r.custom_parent_code? && r.code == code  }

        return [] if selected_row.blank?

        parent_code = selected_row.parent_code
        parent_row = rows.find { |r| r.custom_parent_code? && r.code == parent_code && r.level.present?  }
        level = parent_row.present? ? parent_row.level : selected_row.level - 1

        calculate_custom_parent_codes(selected_row.parent_code) + [OpenStruct.new(code: parent_code, level: level)]
      end

      def custom_parent_codes(code)
        custom_codes_tree[code] || []
      end

      def calculate_accumulated_values
        return if !descending_codes_present?

        rows.each do |row|
          # Calculate aggregations only for rows with code on last level
          next unless last_level?(row.code)

          has_custom_main_code = row.custom_parent_code? || row.custom_level?

          base_index = [row.year, row.raw_area_name, row.kind, row.organization_id]
          parent_codes = has_custom_main_code ? custom_parent_codes(row.code) : row.code_object.parent_codes

          if row.economic_code_object.present?
            # The values only will be accumulated for the first level of code.
            # To have accumulations on deeper levels iterate over
            # parent_codes
            economic_parent_codes = if row.economic_custom?
                                      custom_parent_codes(row.economic_code)
                                    else
                                      row.economic_code_object.parent_codes
                                    end
            code = parent_codes.last.code

            economic_parent_codes.each do |subcode|
              functional_code = row.economic_functional? ? subcode.code : row.functional_code
              custom_code = row.economic_custom? ? subcode.code : row.custom_code

              accumulate(base_index + [code, functional_code, custom_code, "", 1], row)
            end
          else
            parent_codes.each do |pc|
              accumulate(base_index + [pc.code, row.functional_code, row.custom_code, parent_codes.find { |e| e.level == pc.level - 1 }&.code, pc.level], row)
            end
          end
        end
        @extra_rows = @accumulated_values.map do |(year, area_name, kind, organization_id, code, functional_code, custom_code, parent_code, level), values|
          row_values = values.merge(
            "year" => year,
            "code" => code,
            "area" => area_name,
            "kind" => kind,
            "name" => nil,
            "description" => nil,
            "functional_code" => functional_code,
            "custom_code" => custom_code,
            "parent_code" => parent_code,
            "level" => level,
            "organization_id" => organization_id,
            "ID" => nil
          )
          BudgetLineCsvRow.new(CSV::Row.new(row_values.keys, row_values.values))
        end
      end

      def remove_duplicates
        extra_rows.each do |row|
          rows.delete_if do |r|
            [:year, :code, :raw_area_name, :kind, :functional_code, :custom_code].all? { |attr| row.send(attr) == r.send(attr) }
          end
        end
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
