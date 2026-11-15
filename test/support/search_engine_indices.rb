# frozen_string_literal: true

# Elasticsearch indices used by the tests, separate from the development ones.
module SearchEngineIndices
  BUDGETS_INDEX = "test-budgets-forecast"
  DATA_INDEX = "test-data"

  BUDGETS_MAPPING = {
    properties: {
      type: { type: "keyword" },
      ine_code: { type: "integer" },
      organization_id: { type: "keyword" },
      year: { type: "integer" },
      amount: { type: "double" },
      code: { type: "keyword" },
      parent_code: { type: "keyword" },
      functional_code: { type: "keyword" },
      custom_code: { type: "keyword" },
      level: { type: "integer" },
      kind: { type: "keyword" },
      province_id: { type: "integer" },
      autonomy_id: { type: "integer" },
      amount_per_inhabitant: { type: "double" }
    }
  }.freeze

  def self.client
    GobiertoBudgetsData::GobiertoBudgets::SearchEngine.client
  end

  def self.reset
    [BUDGETS_INDEX, DATA_INDEX].each do |index|
      client.indices.delete(index:) if client.indices.exists?(index:)
    end
    client.indices.create(index: BUDGETS_INDEX, body: { mappings: BUDGETS_MAPPING })
    client.indices.create(index: DATA_INDEX)
  end

  def self.add_population(organization_id, year, value, type: "population")
    client.index(index: DATA_INDEX, id: [organization_id, year, type].join("/"), body: { value: }, refresh: true)
  end

  def self.add_budget_lines(documents)
    body = documents.map { |id, data| { index: { _id: id, data: } } }
    client.bulk(index: BUDGETS_INDEX, body:, refresh: true)
  end

  def self.documents(index = BUDGETS_INDEX)
    client.indices.refresh(index:)
    hits = client.search(index:, body: { query: { match_all: {} }, size: 10_000 })["hits"]["hits"]
    hits.to_h { |hit| [hit["_id"], hit["_source"]] }
  end
end
