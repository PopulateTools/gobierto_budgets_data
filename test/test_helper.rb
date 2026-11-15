# frozen_string_literal: true

ENV["ELASTICSEARCH_URL"] ||= "http://localhost:9200"

require "minitest/autorun"
require "active_record"
require_relative "../lib/gobierto_budgets_data"
require_relative "support/budgets_database"
require_relative "support/search_engine_indices"

# elasticsearch-transport 7.17 calls the MultiJson API that multi_json 1.21
# deprecates; minitest enables deprecation warnings, so they flood the output.
module SilenceMultiJsonDeprecations
  def warn(message, category: nil, **)
    super unless category == :deprecated && message.match?(/MultiJS(ON|on)/i)
  end
end
Warning.singleton_class.prepend(SilenceMultiJsonDeprecations)
