# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    # Kind of budget lines
    EXPENSE = "G"
    INCOME = "I"

    ALL_KINDS = [EXPENSE, INCOME].freeze

    # Area names
    ECONOMIC_AREA_NAME = "economic"
    FUNCTIONAL_AREA_NAME = "functional"
    CUSTOM_AREA_NAME = "custom"
    ECONOMIC_FUNCTIONAL_AREA_NAME = "economic-functional"
    ECONOMIC_CUSTOM_AREA_NAME = "economic-custom"

    ALL_AREAS_NAMES = [
      ECONOMIC_AREA_NAME,
      FUNCTIONAL_AREA_NAME,
      CUSTOM_AREA_NAME
    ].freeze

    # Types
    TOTAL_BUDGET_TYPE = "total-budget"
    ECONOMIC_BUDGET_TYPE = ECONOMIC_AREA_NAME
    FUNCTIONAL_BUDGET_TYPE = FUNCTIONAL_AREA_NAME
    CUSTOM_BUDGET_TYPE = CUSTOM_AREA_NAME
    POPULATION_TYPE  = "population"
    DEBT_TYPE  = "debt"
    INVOICE_TYPE = "invoices"

    ALL_TYPES = [
      TOTAL_BUDGET_TYPE,
      ECONOMIC_BUDGET_TYPE,
      FUNCTIONAL_BUDGET_TYPE,
      CUSTOM_BUDGET_TYPE
    ].freeze

    # Elasticsearch indices
    ES_INDEX_FORECAST = "budgets-forecast-v3"
    ES_INDEX_EXECUTED = "budgets-execution-v3"
    ES_INDEX_FORECAST_UPDATED = "budgets-forecast-updated-v1"

    ALL_INDEXES = [
      ES_INDEX_FORECAST,
      ES_INDEX_EXECUTED,
      ES_INDEX_FORECAST_UPDATED
    ].freeze

    ES_INDEX_EXECUTED_SERIES = "gobierto-budgets-execution-series-v1"
    ES_INDEX_DATA = "data"
    ES_INDEX_INVOICES = "invoices"
  end
end
