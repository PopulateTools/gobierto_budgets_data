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
            return client.get(index: index, type: type, id: [ine_code, current_year].join('/'))['_source']['value']
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end
        return nil
      end
    end
  end
end
