# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLineSicalwinRow
      INDEXES_COLUMNS_NAMES_MAPPING = {
        EXPENSE => {
          ES_INDEX_FORECAST => "Créditos Iniciales",
          ES_INDEX_FORECAST_UPDATED => "Créditos Totales consignados",
          ES_INDEX_EXECUTED => "Obligaciones Reconocidas"
        },
        INCOME => {
          ES_INDEX_FORECAST => "Previsiones Iniciales",
          ES_INDEX_FORECAST_UPDATED => "Previsiones totales",
          ES_INDEX_EXECUTED => "Derechos Reconocidos Netos"
        }
      }.freeze

      attr_reader :row, :year, :organization_id

      def initialize(row, options = {})
        @row = row
        @year = options.fetch(:year)
        @organization_id = options.fetch(:organization_id)
        @thousands_separator = options.fetch(:thousands_separator, ",")
        @decimal_separator = options.fetch(:decimal_separator, ".")
      end

      def amount(index)
        raw_value = row.field(INDEXES_COLUMNS_NAMES_MAPPING[kind][index])
        return raw_value if raw_value.is_a? Numeric
        return 0.0 unless raw_value.is_a? String

        raw_value.delete(@thousands_separator).tr(@decimal_separator, ".").to_f
      end

      def kind
        @kind ||= row.has_key?("Pro.") ? EXPENSE : INCOME
      end

      def description
        @description ||= row.field("Descripción")
      end

      def area_code(area_name)
        code = case area_name
               when ECONOMIC_AREA_NAME
                 row["Eco."]
               when FUNCTIONAL_AREA_NAME, ECONOMIC_FUNCTIONAL_AREA_NAME
                 row["Pro."]
               when CUSTOM_AREA_NAME, ECONOMIC_CUSTOM_AREA_NAME
                 kind == EXPENSE ? [row["Org."], row["Pro."], row["Eco."]].join("-") : [row["Org."], row["Eco."]].join("-")
               else
                 raise "Unknown area name: #{area_name}"
               end

        if code.blank?
          raise "Missing code for #{area_name} in row #{row}"
        end

        return code if area_name == CUSTOM_AREA_NAME

        # The CSV format removes leading zeros
        if code.length == 4
          code = "0#{code}"
        end

        # Import only three levels of data
        return code[0..2]
      end
    end
  end
end
