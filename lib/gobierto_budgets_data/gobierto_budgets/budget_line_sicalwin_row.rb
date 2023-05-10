# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLineSicalwinRow
      INDEXES_COLUMNS_NAMES_MAPPING_ES = {
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

      INDEXES_COLUMNS_NAMES_MAPPING_CA = {
        EXPENSE => {
          ES_INDEX_FORECAST => "Crèdits inicials",
          ES_INDEX_FORECAST_UPDATED => "Crèdits totals consignats",
          ES_INDEX_EXECUTED => "Obligacions reconegudes"
        },
        INCOME => {
          ES_INDEX_FORECAST => "Previsions inicials",
          ES_INDEX_FORECAST_UPDATED => "Previsions totals",
          ES_INDEX_EXECUTED => "Drets Reconeguts nets"
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
        column_name_es = INDEXES_COLUMNS_NAMES_MAPPING_ES[kind][index]
        column_name_ca = INDEXES_COLUMNS_NAMES_MAPPING_CA[kind][index]
        raw_value = row.has_key?(column_name_es) ? row.field(column_name_es) : row.field(column_name_ca)
        return raw_value if raw_value.is_a? Numeric
        return 0.0 unless raw_value.is_a? String

        raw_value.delete(@thousands_separator).tr(@decimal_separator, ".").to_f
      end

      def kind
        @kind ||= row.has_key?("Pro.") ? EXPENSE : INCOME
      end

      def description
        @description ||= row.has_key?("Descripción") ? row.field("Descripción") : row.field("Descripció")
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

        # This specific rule was added for the case of Dip. Huelva
        # It might require to re-adjust the data
        # if code.length == 4
        #   code = "0#{code}"
        # end

        # Import only three levels of data
        return code[0..2]
      end
    end
  end
end
