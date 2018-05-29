# frozen_string_literal: true

require "elasticsearch"

module GobiertoData
  module GobiertoBudgets
    class SearchEngine
      def self.client
        @client ||= Elasticsearch::Client.new log: false, url: ENV["ELASTIC_SEARCH_URL"]
      end
    end
  end
end
