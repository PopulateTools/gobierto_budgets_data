# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    # Indexes documents with bulk requests of batch_size documents. While it is
    # open the index neither refreshes nor replicates, so loading a whole year
    # is much faster; the previous settings come back when it closes.
    class BulkIndexer
      class Error < StandardError; end

      BATCH_SIZE = 5_000
      FAILURES_IN_MESSAGE = 5

      def self.open(client:, index:, batch_size: BATCH_SIZE)
        indexer = new(client:, index:, batch_size:)
        indexer.loading do
          yield indexer
          indexer.flush
        end
      end

      def initialize(client:, index:, batch_size:)
        @client = client
        @index = index
        @batch_size = batch_size
        @documents = []
      end

      def add(id, data)
        @documents << { index: { _id: id, data: } }
        flush if @documents.size >= @batch_size
      end

      def flush
        return if @documents.empty?

        response = @client.bulk(index: @index, body: @documents)
        @documents = []
        raise Error, failures_message(response) if response["errors"]
      end

      def loading
        previous_settings = current_settings
        update_settings("refresh_interval" => "-1", "number_of_replicas" => 0)
        yield
      ensure
        update_settings(previous_settings) if previous_settings
        @client.indices.refresh(index: @index)
      end

      private

      def current_settings
        settings = @client.indices.get_settings(index: @index).values.first["settings"]["index"]
        { "refresh_interval" => settings["refresh_interval"], "number_of_replicas" => settings["number_of_replicas"] }
      end

      def update_settings(settings)
        @client.indices.put_settings(index: @index, body: { index: settings })
      end

      def failures_message(response)
        failures = response["items"].map { |item| item.values.first }.select { |result| result["error"] }
        details = failures.first(FAILURES_IN_MESSAGE).map { |result| "#{result["_id"]}: #{result["error"]["reason"]}" }

        "#{failures.size} documents rejected by #{@index}. #{details.join("; ")}"
      end
    end
  end
end
