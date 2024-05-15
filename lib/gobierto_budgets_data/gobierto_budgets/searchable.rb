module GobiertoBudgetsData
  module GobiertoBudgets
    module Searchable
      extend ActiveSupport::Concern

      class_methods do

        def all_items
          @all_items ||= begin
            all_items = {}

            I18n.available_locales.each do |locale|
              all_items[locale] ||= {}
              GobiertoBudgetsData::GobiertoBudgets::ALL_AREAS_NAMES.each do |area_name|
                spec = Gem::Specification.find_by_name "gobierto_budgets_data"

                file_path = "#{spec.gem_dir}/data/gobierto_budgets/#{area_name}_#{locale}.json"
                next unless File.exist?(file_path)
                all_items[locale][area_name] ||= Oj.load(File.read(file_path))
              end
            end

            all_items
          end

          @all_items[I18n.locale][area_name] || {"G" => {}, "I" => {}}
        end

      end
    end
  end
end
