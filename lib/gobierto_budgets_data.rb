# frozen_string_literal: true

require "bundler/setup"
Bundler.require

require "i18n"
require "oj"
require "active_support/all"
require "ine/places"

module GobiertoBudgetsData
  I18n.available_locales = [:es, :en, :ca]
end

require_relative "gobierto_budgets_data/file_uploader"
require_relative "gobierto_budgets_data/gobierto_budgets/configuration"
require_relative "gobierto_budgets_data/gobierto_budgets/search_engine"
require_relative "gobierto_budgets_data/gobierto_budgets/search_engine_writing"
require_relative "gobierto_budgets_data/gobierto_budgets/population"
require_relative "gobierto_budgets_data/gobierto_budgets/budget_line_presenter"
require_relative "gobierto_budgets_data/gobierto_budgets/total_budget_calculator"
require_relative "gobierto_budgets_data/gobierto_budgets/category"
require_relative "gobierto_budgets_data/gobierto_budgets/budget_line"
require_relative "gobierto_budgets_data/gobierto_budgets/bubbles"
require_relative "gobierto_budgets_data/gobierto_budgets/budget_lines_importer"
require_relative "gobierto_budgets_data/gobierto_budgets/budget_lines_csv_importer"
require_relative "gobierto_budgets_data/gobierto_budgets/custom_categories_csv_importer"
require_relative "gobierto_budgets_data/gobierto_budgets/budget_line_code"
require_relative "gobierto_budgets_data/gobierto_budgets/budget_line_csv_row"
require_relative "gobierto_budgets_data/gobierto_budgets/invoice_csv_row"
require_relative "gobierto_budgets_data/gobierto_budgets/invoices_importer"
require_relative "gobierto_budgets_data/gobierto_budgets/invoices_csv_importer"
require_relative "populate_data/client"
