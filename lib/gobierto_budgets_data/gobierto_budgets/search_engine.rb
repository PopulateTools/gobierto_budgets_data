# frozen_string_literal: true

require "elasticsearch"

module GobiertoBudgetsData
  module GobiertoBudgets
    class SearchEngine
      def self.client
        @client ||= Elasticsearch::Client.new log: false, url: ENV.fetch("ELASTICSEARCH_URL")
      end
    end
  end
end
