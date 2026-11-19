# frozen_string_literal: true

require "test_helper"

class SyncBudgetsDataTest < Minitest::Test
  def test_loads
    require_relative "../lib/gobierto_budgets_data/gobierto_budgets/utils/sync_budgets_data"

    assert defined?(GobiertoBudgetsData::GobiertoBudgets::Utils::SyncBudgetsData)
  end
end
