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

        @parent_code ||= code[0..level - 2]
      end

      def parent_codes
        return [] unless parent_code.present?

        pc = parent_code
        codes = [pc]

        while (pc = self.class.new(pc).parent_code).present?
          codes.append(pc)
        end

        codes
      end
    end
  end
end
