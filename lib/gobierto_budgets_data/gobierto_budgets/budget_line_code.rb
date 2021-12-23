# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLineCode
      attr_reader :code, :errors

      def initialize(code)
        @code = code.to_s.strip
        @errors = {}
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

        @parent_codes ||= begin
                            pc = OpenStruct.new(code: parent_code, level: level - 1)
                            codes = [pc]

                            while (pc = OpenStruct.new(code: self.class.new(pc.code).parent_code, level: pc.level - 1)) && pc.code.present?
                              codes.append(pc)
                            end

                            codes
                          end
      end

      def valid?
        return true if digits == code.tr("-", "").strip

        @errors.merge!(code: "\"#{code}\" contains invalid non numeric characters")

        false
      end
    end
  end
end
