# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLineCsvRow
      # economic-functional, economic-custom
      AREA_VALUES_MAPPING = {
        "economic-functional" => ECONOMIC_AREA_NAME,
        "economic-custom" => ECONOMIC_AREA_NAME,
        "economic" => ECONOMIC_AREA_NAME,
        "functional" => FUNCTIONAL_AREA_NAME,
        "custom" => CUSTOM_AREA_NAME
      }

      KIND_VALUES_MAPPING = {
        "I" => INCOME,
        "E" => EXPENSE
      }

      INDEXES_COLUMNS_NAMES_MAPPING = {
        "initial_value" => ES_INDEX_FORECAST,
        "modified_value" => ES_INDEX_FORECAST_UPDATED,
        "executed_value" => ES_INDEX_EXECUTED
      }

      attr_reader :row, :errors, :thousands_separator, :decimal_separator

      delegate :code, to: :code_object

      def initialize(row, opts = {})
        @row = row
        @thousands_separator = opts.fetch(:thousands_separator, ",")
        @decimal_separator = opts.fetch(:decimal_separator, ".")
        @errors = {}
      end

      def value(index)
        raw_value = row.field(INDEXES_COLUMNS_NAMES_MAPPING.key(index))
        return raw_value if raw_value.is_a? Numeric
        return 0.0 unless raw_value.is_a? String

        raw_value.delete(thousands_separator).tr(decimal_separator, ".").to_f
      end

      def year
        row.field("year").to_i
      end

      def kind
        @kind ||= KIND_VALUES_MAPPING[row.field("kind")]
      end

      def raw_area_name
        @raw_area_name ||= row.field("area")
      end

      def area_name
        @area_name ||= AREA_VALUES_MAPPING[raw_area_name]
      end

      def economic_functional?
        raw_area_name == "economic-functional"
      end

      def economic_custom?
        raw_area_name == "economic-custom"
      end

      def economic_code_object
        @economic_code_object ||= if economic_functional?
                                    BudgetLineCode.new(row.field("functional_code"))
                                  elsif economic_custom?
                                    BudgetLineCode.new(row.field("custom_code"))
                                  end
      end

      def economic_code
        economic_code_object.code
      end

      def economic_code_data
        return {} unless economic_code_object.present?

        { economic_functional? ? "functional_code" : "custom_code" => economic_code }
      end

      def functional_code
        @functional_code ||= row.field("functional_code")
      end

      def custom_code
        @custom_code ||= row.field("custom_code")
      end

      def code_object
        @code_object ||= BudgetLineCode.new(row.field("code"))
      end

      def level
        return row.field("level").to_i if custom_parent_code?

        (row.field("level").presence || code_object.level).to_i
      end

      def custom_parent_code?
        area_name == CUSTOM_AREA_NAME && row.field("parent_code").present?
      end

      def custom_level?
        area_name == CUSTOM_AREA_NAME && row.field("level").present?
      end

      def parent_code
        return row.field("parent_code") if custom_level?

        row.field("parent_code").presence || code_object.parent_code
      end

      def organization_id
        row.field("organization_id")
      end

      def place
        return unless organization_id =~ /^\d+$/

        @place ||= ::INE::Places::Place.find(organization_id)
      end

      def ine_code
        place&.id.try(:to_i)
      end

      def province_id
        place&.province&.id.try(:to_i)
      end

      def autonomy_id
        place&.province&.autonomous_region&.id.try(:to_i)
      end

      def population
        @population ||= GobiertoBudgetsData::GobiertoBudgets::Population.get(ine_code, year)
      end

      def amount_per_inhabitant(index)
        return unless population.present?

        (value(index) / population).round(2)
      end

      def id
        row.field("ID").presence || automatic_id
      end

      def automatic_id
        [
          organization_id,
          year,
          area_code,
          kind,
          area_name
        ].join("/")
      end

      def area_code
        case row.field("area")
        when "economic-custom"
          [row.field("custom_code"), code, "c"].join("/")
        when "economic-functional"
          [row.field("functional_code"), code, "f"].join("/")
        else
          code
        end
      end

      def unavailable_custom_category?
        return unless area_name == CUSTOM_AREA_NAME

        ::GobiertoBudgets::Category.joins(:site).where(
          sites: { organization_id: organization_id },
          kind: kind,
          code: code,
          area_name: area_name
        ).empty?
      end

      def budget_line(index)
        {
          "organization_id": organization_id,
          "ine_code": ine_code,
          "province_id": province_id,
          "autonomy_id": autonomy_id,
          "year": year,
          "population": population,
          "amount": value(index),
          "code": code,
          "level": level,
          "kind": kind,
          "amount_per_inhabitant": amount_per_inhabitant(index),
          "parent_code": parent_code,
          "type": area_name
        }.merge(economic_code_data)
      end

      def data
        INDEXES_COLUMNS_NAMES_MAPPING.map do |column_name, index|
          next unless row.field(column_name).present?

          {
            index: {
              _index: index,
              _id: id,
              data: budget_line(index)
            }
          }
        end.compact
      end

      def valid?
        return true if code_object.valid?

        @errors.merge!(code_object.errors)

        false
      end
    end
  end
end
