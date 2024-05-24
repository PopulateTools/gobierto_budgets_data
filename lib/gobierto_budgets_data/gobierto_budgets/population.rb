# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class Population
      def self.get(ine_code, year)
        index = GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
        type  = GobiertoBudgetsData::GobiertoBudgets::POPULATION_TYPE
        client = GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client
        year.downto(year-2).each do |current_year|
          begin
            return client.get(index: index, id: [ine_code, current_year, type].join('/'))['_source']['value']
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end
        return nil
      end
    end
  end
end
