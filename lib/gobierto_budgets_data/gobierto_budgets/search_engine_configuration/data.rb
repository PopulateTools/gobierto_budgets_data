# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    module SearchEngineConfiguration
      class Data

        def self.index
          GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
        end

        def self.type_population
          GobiertoBudgetsData::GobiertoBudgets::POPULATION_TYPE
        end

        def self.type_debt
          GobiertoBudgetsData::GobiertoBudgets::DEBT_TYPE
        end

      end
    end
  end
end
