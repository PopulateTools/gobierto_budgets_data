# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLineCode
      attr_reader :code, :errors

      def initialize(code, attrs = {})
        @errors = {}
        @code = code.to_s.strip
        @custom_category = if attrs[:organization_id].present? && attrs[:kind].present? && attrs[:area_name].present?
                             custom_category = ::GobiertoBudgets::Category.joins(:site).find_by(
                               sites: { organization_id: attrs[:organization_id] },
                               kind: attrs[:kind],
                               code: @code,
                               area_name: attrs[:area_name]
                             )

                             if custom_category.nil?
                               @errors[:missing_custom_category] = @code
                               puts "Custom category not found for code #{@code} and attrs: #{attrs}" if @code.length > 3
                             end

                             custom_category
                           end
      end

      def digits
        @digits ||= code.gsub(/[^\d]/,"")
      end

      def level
        @level ||= if @custom_category
                     digits.length > 1 ? 2 : 1
                   else
                     [4, digits.length].min
                   end
      end

      def ancestor_code
        return OpenStruct.new(code: @custom_category.parent_code, level: 1) if @custom_category
        return nil unless parent_code.present?
        return OpenStruct.new(code: code[0], level: 1)
      end

      def parent_code
        return @custom_category.parent_code if @custom_category
        return if level < 2

        @parent_code ||= code[0..level - 2]
      end

      def parent_codes
        if @custom_category
          # In custom categories there's just two levels of hierarchy
          return [OpenStruct.new(code: @custom_category.parent_code, level: 1)]
        end
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
        return true if @custom_category
        return true if digits == code.tr("-", "").strip

        @errors.merge!(code: "\"#{code}\" contains invalid non numeric characters")

        puts @errors

        false
      end
    end
  end
end
