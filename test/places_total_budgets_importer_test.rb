# frozen_string_literal: true

require "test_helper"

class PlacesTotalBudgetsImporterTest < Minitest::Test
  PlaceDecorator = GobiertoBudgetsData::GobiertoBudgets::PlaceDecorator
  PlacesTotalBudgetsImporter = GobiertoBudgetsData::GobiertoBudgets::PlacesTotalBudgetsImporter

  def setup
    SearchEngineIndices.reset
  end

  def places
    %w(28079 8019 28065).map { |id| PlaceDecorator.find(id) }
  end

  def budget_line(organization_id, ine_code, code, kind, type, amount, amount_per_inhabitant, level: code.length, year: 2025, **attributes)
    id = [organization_id, year, code, kind, type, attributes.values].flatten.join("/")
    data = { organization_id:, ine_code:, year:, code:, kind:, type:, level:, amount:, amount_per_inhabitant:, **attributes }
    [id, data]
  end

  def import
    PlacesTotalBudgetsImporter.new(
      client: SearchEngineIndices.client,
      index: SearchEngineIndices::BUDGETS_INDEX,
      year: 2025,
      places:
    ).import
  end

  def total_budget(attributes, kind, amount, amount_per_inhabitant)
    attributes.merge("year" => 2025, "kind" => kind, "amount" => amount, "amount_per_inhabitant" => amount_per_inhabitant, "type" => "total-budget")
  end

  def test_import
    SearchEngineIndices.add_budget_lines([
      budget_line("28079", 28079, "1", "G", "functional", 100.0, 0.1),
      budget_line("28079", 28079, "2", "G", "functional", 50.5, 0.05),
      budget_line("28079", 28079, "11", "G", "functional", 70.0, 0.07),
      budget_line("28079", 28079, "1", "G", "functional", 999.0, 0.9, year: 2024),
      budget_line("28079", 28079, "1", "G", "economic", 400.0, 0.4),
      budget_line("28079", 28079, "1", "G", "economic", 30.0, 0.03, functional_code: "1"),
      budget_line("28079", 28079, "4", "I", "economic", 2000.0, 2.0),
      budget_line("28079", 28079, "4", "I", "economic", 5.0, 0.01, custom_code: "4-01"),
      budget_line("8019", 8019, "1", "G", "economic", 300.0, 3.0),
      budget_line("8019", 8019, "3", "G", "economic", 20.0, 0.2)
    ])

    import

    madrid = { "ine_code" => 28079, "province_id" => 28, "autonomy_id" => 13, "organization_id" => "28079" }
    barcelona = { "ine_code" => 8019, "province_id" => 8, "autonomy_id" => 9, "organization_id" => "8019" }
    getafe = { "ine_code" => 28065, "province_id" => 28, "autonomy_id" => 13, "organization_id" => "28065" }
    totals = SearchEngineIndices.documents.select { |id, _| id.end_with?("total-budget") }

    assert_equal({
      "28079/2025/G/total-budget" => total_budget(madrid, "G", 150.5, 0.15),
      "28079/2025/I/total-budget" => total_budget(madrid, "I", 2000.0, 2.0),
      "8019/2025/G/total-budget" => total_budget(barcelona, "G", 320.0, 3.2),
      "8019/2025/I/total-budget" => total_budget(barcelona, "I", 0.0, 0.0),
      "28065/2025/G/total-budget" => total_budget(getafe, "G", 0.0, 0.0),
      "28065/2025/I/total-budget" => total_budget(getafe, "I", 0.0, 0.0)
    }, totals)
  end
end
