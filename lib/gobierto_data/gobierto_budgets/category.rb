# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class Category
      def self.all(options)
        area_name = options.fetch(:area_name)
        kind      = options.fetch(:kind)
        locale    = options.fetch(:locale).to_s

        categories_data[locale][area_name][kind]
      end

      def self.categories_data
        @categories_data ||= Oj.load(File.read(File.expand_path("../../../../data/gobierto_budgets/categories.json", __FILE__)))
      end
    end
  end
end
