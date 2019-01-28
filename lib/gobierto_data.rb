# frozen_string_literal: true

require "bundler/setup"
Bundler.require

require "i18n"
require "oj"
require "active_support/all"
require "ine/places"

module GobiertoData
  I18n.available_locales = [:es, :en, :ca]
end

require_relative "gobierto_data/file_uploader"
require_relative "gobierto_data/gobierto_budgets/configuration"
require_relative "gobierto_data/gobierto_budgets/search_engine"
require_relative "gobierto_data/gobierto_budgets/population"
require_relative "gobierto_data/gobierto_budgets/budget_line_presenter"
require_relative "gobierto_data/gobierto_budgets/total_budget_calculator"
require_relative "gobierto_data/gobierto_budgets/category"
require_relative "gobierto_data/gobierto_budgets/budget_line"
require_relative "gobierto_data/gobierto_budgets/bubbles"
require_relative "gobierto_data/gobierto_budgets/budget_lines_importer"
require_relative "gobierto_data/gobierto_budgets/invoices_importer"
