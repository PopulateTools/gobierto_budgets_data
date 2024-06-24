# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class Population
      INDEX = GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_DATA
      TYPE = GobiertoBudgetsData::GobiertoBudgets::POPULATION_TYPE
      ALLOWED_SEARCH_KEYS = [:organization_id, :ine_code, :year, :province_id, :autonomy_id]

      def self.get(ine_code, year)
        year.downto(year-2).each do |current_year|
          begin
            return client.get(index: INDEX, id: [ine_code, current_year, TYPE].join('/'))['_source']['value']
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end
        return nil
      end

      # Returns a result of searching by population type and any of the allowed
      # search keys
      def self.get_by(options = {})
        terms = [{ term: { type: "population" } }]

        options.slice(*ALLOWED_SEARCH_KEYS).each do |term, value|
          terms << { term: { term => value } }
        end

        body = {
          query: { bool: { must: terms } },
          size: 10_000
        }

        result = begin
          client.search(
            index: INDEX,
            body: body
          )
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
        end

        result.presence && result["hits"]["hits"]
      end

      def self.client
        GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client
      end
    end
  end
end
