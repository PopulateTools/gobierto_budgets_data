# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    module SearchEngineConfiguration
      class BudgetLine

        def self.all_indices
          [index_forecast, index_executed, index_forecast_updated]
        end

        def self.index_forecast
          GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_FORECAST
        end

        def self.index_executed
          GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_EXECUTED
        end

        def self.index_forecast_updated
          GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_FORECAST_UPDATED
        end
      end
    end
  end
end
