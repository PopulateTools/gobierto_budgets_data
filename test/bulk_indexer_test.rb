# frozen_string_literal: true

require "test_helper"

class BulkIndexerTest < Minitest::Test
  BulkIndexer = GobiertoBudgetsData::GobiertoBudgets::BulkIndexer

  def setup
    SearchEngineIndices.reset
    client.indices.put_settings(index:, body: { index: { refresh_interval: "7s", number_of_replicas: 1 } })
  end

  def client
    SearchEngineIndices.client
  end

  def index
    SearchEngineIndices::BUDGETS_INDEX
  end

  def settings
    client.indices.get_settings(index:)[index]["settings"]["index"].slice("refresh_interval", "number_of_replicas")
  end

  def test_indexes_documents_in_batches
    BulkIndexer.open(client:, index:, batch_size: 2) do |indexer|
      3.times { |i| indexer.add("doc-#{i}", { "code" => i.to_s }) }
    end

    assert_equal %w(doc-0 doc-1 doc-2), SearchEngineIndices.documents.keys.sort
  end

  def test_disables_refresh_and_replicas_while_indexing
    settings_while_indexing = nil

    BulkIndexer.open(client:, index:) { settings_while_indexing = settings }

    assert_equal({ "refresh_interval" => "-1", "number_of_replicas" => "0" }, settings_while_indexing)
    assert_equal({ "refresh_interval" => "7s", "number_of_replicas" => "1" }, settings)
  end

  def test_restores_default_refresh_interval
    client.indices.put_settings(index:, body: { index: { refresh_interval: nil } })

    BulkIndexer.open(client:, index:) { |indexer| indexer.add("doc", { "code" => "1" }) }

    assert_equal({ "number_of_replicas" => "1" }, settings)
  end

  def test_restores_settings_when_indexing_fails
    assert_raises(RuntimeError) do
      BulkIndexer.open(client:, index:) { raise "boom" }
    end

    assert_equal({ "refresh_interval" => "7s", "number_of_replicas" => "1" }, settings)
  end
end
