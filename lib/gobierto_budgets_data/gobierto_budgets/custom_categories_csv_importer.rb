# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class CustomCategoriesCsvImporter
      attr_reader :csv, :site, :locale

      def initialize(csv, **opts)
        @csv = csv
        @site = opts.fetch(:site)
        @locale = opts.fetch(:locale, site.configuration.default_locale).to_s
      end

      def import!
        updated = created = 0

        csv.each do |row|
          name_translations = { locale => row.field("name") }
          kinds.each do |kind|
            category_attrs = {
              site: site,
              area_name: CUSTOM_AREA_NAME,
              kind: kind,
              code: row.field("code"),
              parent_code: row.field("parent_code")
            }
            if (category = ::GobiertoBudgets::Category.where(category_attrs).first)
              category.update!(custom_name_translations: (category.custom_name_translations.presence || {}).merge(name_translations))
              updated += 1
            else
              ::GobiertoBudgets::Category.create!(
                category_attrs.merge(custom_name_translations: name_translations)
              )
              created += 1
            end

          end
        end

        created + updated
      end

      private

      def kinds
        [EXPENSE, INCOME]
      end
    end
  end
end
