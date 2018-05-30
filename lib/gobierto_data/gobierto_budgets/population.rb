# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    class Population
      def self.get(ine_code, year)
        index = GobiertoData::GobiertoBudgets::ES_INDEX_DATA
        type  = GobiertoData::GobiertoBudgets::POPULATION_TYPE
        client = GobiertoData::GobiertoBudgets::SearchEngine.client
        year.downto(year-2).each do |current_year|
          begin
            return client.get(index: index, type: type, id: [ine_code, current_year].join('/'))['_source']['value']
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end
      end
    end
  end
end
