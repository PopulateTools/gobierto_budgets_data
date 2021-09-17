# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class BudgetLineCode
      attr_reader :code

      def initialize(code)
        @code = code.to_s
      end

      def digits
        @digits ||= code.gsub(/[^\d]/,"")
      end

      def level
        @level ||= [4, digits.length].min
      end

      def parent_code
        return if level < 2

        code[0..level - 2]
      end
    end
  end
end
