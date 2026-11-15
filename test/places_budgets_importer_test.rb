# frozen_string_literal: true

require "test_helper"

class PlacesBudgetsImporterTest < Minitest::Test
  PlaceDecorator = GobiertoBudgetsData::GobiertoBudgets::PlaceDecorator
  PlacesBudgetsImporter = GobiertoBudgetsData::GobiertoBudgets::PlacesBudgetsImporter

  INVENTORY = [
    { idente: 1, codente: "28079AA000" },
    { idente: 2, codente: "08019AA000" },
    { idente: 3, codente: "28065AA000" },
    { idente: 4, codente: "99999AA000" }
  ].freeze

  def setup
    SearchEngineIndices.reset
    SearchEngineIndices.add_population(28079, 2025, 1000)
    SearchEngineIndices.add_population(8019, 2024, 100)
  end

  def places
    %w(28079 8019 28065).map { |id| PlaceDecorator.find(id) }
  end

  def import(type, year: 2025)
    importer = PlacesBudgetsImporter.new(
      db: BudgetsDatabase.connection,
      client: SearchEngineIndices.client,
      index: SearchEngineIndices::BUDGETS_INDEX,
      population_index: SearchEngineIndices::DATA_INDEX,
      year:,
      destination_year: year,
      places:
    )
    importer.import(type)
  end

  def madrid_attributes
    { "ine_code" => 28079, "province_id" => 28, "autonomy_id" => 13, "organization_id" => "28079", "year" => 2025, "population" => 1000 }
  end

  def barcelona_attributes
    { "ine_code" => 8019, "province_id" => 8, "autonomy_id" => 9, "organization_id" => "8019", "year" => 2025, "population" => 100 }
  end

  def test_import_economic
    BudgetsDatabase.create_tables(2025, inventory: INVENTORY, economic: [
      { idente: 1, tipreig: "G", cdcta: "1", importe: 1000 },
      { idente: 1, tipreig: "G", cdcta: "12", importe: 600 },
      { idente: 1, tipreig: "G", cdcta: "222.01", importe: 50.5 },
      { idente: 1, tipreig: "I", cdcta: "4", importe: 2000 },
      { idente: 2, tipreig: "G", cdcta: "1", importe: 300 },
      { idente: 3, tipreig: "G", cdcta: "1", importe: 700 },
      { idente: 4, tipreig: "G", cdcta: "1", importe: 900 }
    ])

    output, = capture_io { import("economic") }

    assert_equal "- Skipping 28065 Getafe because population data is missing for 2025 and 2024\n", output
    assert_equal({
      "28079/2025/1/G/economic" => madrid_attributes.merge("type" => "economic", "amount" => 1000.0, "code" => "1", "level" => 1, "kind" => "G", "amount_per_inhabitant" => 1.0, "parent_code" => ""),
      "28079/2025/12/G/economic" => madrid_attributes.merge("type" => "economic", "amount" => 600.0, "code" => "12", "level" => 2, "kind" => "G", "amount_per_inhabitant" => 0.6, "parent_code" => "1"),
      "28079/2025/222-01/G/economic" => madrid_attributes.merge("type" => "economic", "amount" => 50.5, "code" => "222-01", "level" => 4, "kind" => "G", "amount_per_inhabitant" => 0.05, "parent_code" => "222"),
      "28079/2025/4/I/economic" => madrid_attributes.merge("type" => "economic", "amount" => 2000.0, "code" => "4", "level" => 1, "kind" => "I", "amount_per_inhabitant" => 2.0, "parent_code" => ""),
      "8019/2025/1/G/economic" => barcelona_attributes.merge("type" => "economic", "amount" => 300.0, "code" => "1", "level" => 1, "kind" => "G", "amount_per_inhabitant" => 3.0, "parent_code" => "")
    }, SearchEngineIndices.documents)
  end

  def test_import_economic_from_recognized_and_forecast_amount_columns
    BudgetsDatabase.create_tables(2010, inventory: INVENTORY, economic_amount_columns: %w(importer imported), economic: [
      { idente: 1, tipreig: "G", cdcta: "1", importer: 0, imported: 70 },
      { idente: 1, tipreig: "I", cdcta: "4", importer: 80, imported: 90 }
    ])
    SearchEngineIndices.add_population(28079, 2010, 10)

    capture_io { import("economic", year: 2010) }

    amounts = SearchEngineIndices.documents.transform_values { |document| document["amount"] }
    assert_equal({ "28079/2010/1/G/economic" => 70.0, "28079/2010/4/I/economic" => 80.0 }, amounts)
  end

  def test_import_functional
    BudgetsDatabase.create_tables(2025, inventory: INVENTORY, functional: [
      { idente: 1, cdfgr: "1", cdcta: "12", importe: 100 },
      { idente: 1, cdfgr: "1", cdcta: "13", importe: 50 },
      { idente: 1, cdfgr: "15", cdcta: "12", importe: 30 },
      { idente: 1, cdfgr: "151.01", cdcta: "12", importe: 20 },
      { idente: 4, cdfgr: "1", cdcta: "12", importe: 900 }
    ])

    capture_io { import("functional") }

    assert_equal({
      "28079/2025/1/G/functional" => madrid_attributes.merge("amount" => 150.0, "code" => "1", "level" => 1, "kind" => "G", "amount_per_inhabitant" => 0.15, "parent_code" => "", "type" => "functional"),
      "28079/2025/15/G/functional" => madrid_attributes.merge("amount" => 30.0, "code" => "15", "level" => 2, "kind" => "G", "amount_per_inhabitant" => 0.03, "parent_code" => "1", "type" => "functional"),
      "28079/2025/151-01/G/functional" => madrid_attributes.merge("amount" => 20.0, "code" => "151-01", "level" => 4, "kind" => "G", "amount_per_inhabitant" => 0.02, "parent_code" => "151", "type" => "functional"),
      "28079/2025/12-1/G/economic" => madrid_attributes.merge("amount" => 100.0, "code" => "12", "functional_code" => "1", "kind" => "G", "amount_per_inhabitant" => 0.1, "type" => "economic"),
      "28079/2025/13-1/G/economic" => madrid_attributes.merge("amount" => 50.0, "code" => "13", "functional_code" => "1", "kind" => "G", "amount_per_inhabitant" => 0.05, "type" => "economic"),
      "28079/2025/12-15/G/economic" => madrid_attributes.merge("amount" => 30.0, "code" => "12", "functional_code" => "15", "kind" => "G", "amount_per_inhabitant" => 0.03, "type" => "economic"),
      "28079/2025/12-151-01/G/economic" => madrid_attributes.merge("amount" => 20.0, "code" => "12", "functional_code" => "151-01", "kind" => "G", "amount_per_inhabitant" => 0.02, "type" => "economic")
    }, SearchEngineIndices.documents)
  end

  def test_import_raises_when_the_search_engine_rejects_documents
    SearchEngineIndices.client.indices.delete(index: SearchEngineIndices::BUDGETS_INDEX)
    SearchEngineIndices.client.indices.create(index: SearchEngineIndices::BUDGETS_INDEX, body: { mappings: { properties: { code: { type: "integer" } } } })
    BudgetsDatabase.create_tables(2025, inventory: INVENTORY, economic: [
      { idente: 1, tipreig: "G", cdcta: "222.01", importe: 50.5 }
    ])

    error = assert_raises(GobiertoBudgetsData::GobiertoBudgets::BulkIndexer::Error) do
      capture_io { import("economic") }
    end
    assert_match "28079/2025/222-01/G/economic", error.message
  end
end
