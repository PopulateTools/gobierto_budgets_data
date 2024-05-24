module GobiertoBudgetsData
  module GobiertoBudgets
    module Describable
      extend ActiveSupport::Concern

      class_methods do
        def all_descriptions
          @all_descriptions ||= begin
                                  Hash[I18n.available_locales.map do |locale|
                                    spec = Gem::Specification.find_by_name "gobierto_budgets_data"
                                    path = "#{spec.gem_dir}/data/gobierto_budgets/budget_line_descriptions_#{locale}.yml"
                                    [locale, YAML.load_file(path)]
                                  end]
                                end
        end
      end
    end
  end
end
