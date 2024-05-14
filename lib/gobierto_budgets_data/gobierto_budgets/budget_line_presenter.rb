# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLinePresenter

      def initialize(attributes)
        @attributes = attributes.symbolize_keys
      end

      def id
        @attributes.values_at(:organization_id, :year, :code, :kind, :area_name, :type).join("/")
      end

      def amount
        @attributes[:amount]
      end

      def amount_per_inhabitant
        @attributes[:amount_per_inhabitant]
      end

      def attr
        @attributes
      end

      # TODO: might change to @attributes[:amount]
      def total
        @attributes[:total]
      end

      # TODO: might change to @attributes[:amount_per_inhabitant]
      def total_per_inhabitant
        @attributes[:total_budget_per_inhabitant]
      end

      def code
        @attributes[:code]
      end

      def level
        @attributes[:level]
      end

      def kind
        @attributes[:kind]
      end

      def area_name
        @attributes[:area_name]
      end

      def year
        @attributes[:year]
      end

      def parent_code
        @attributes[:parent_code].to_s
      end

      def to_param
        {
          id: code,
          year: year,
          kind: kind,
          area_name: area_name
        }
      end
    end
  end
end
