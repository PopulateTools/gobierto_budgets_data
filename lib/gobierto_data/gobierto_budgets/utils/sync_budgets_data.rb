# frozen_string_literal: true

module GobiertoData
  module GobiertoBudgets
    module Utils
      class SyncBudgetsData
        def initialize(from_url, to_url, ine_code)
          @from = Elasticsearch::Client.new log: false, url: from_url
          @to = Elasticsearch::Client.new log: false, url: to_url
          @ine_code = ine_code
        end

        def sync(year)
          [
            GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST,
            GobiertoData::GobiertoBudgets::ES_INDEX_EXECUTED,
          ].each do |index|
            [
              GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME,
              GobiertoData::GobiertoBudgets::FUNCTIONAL_AREA_NAME
            ].each do |type|
              terms = [{term: { ine_code: @ine_code } }, { term: { year: year } } ]
              results = @from.search(index: index, type: type, body: { query: { filtered: { filter: { bool: { must: terms }}}}, size: 10_000 })
              puts results['hits']['total']
              results['hits']['hits'].each { |hit| hit['data'] = hit.delete('_source') }
              results['hits']['hits'].each { |hit| hit.delete('_score') }
              response = @to.bulk(body: results['hits']['hits'].map{ |h| { index: h }})
              if response['errors']
                puts "Errors!"
                raise
              end
            end
          end
        end
      end
    end
  end
