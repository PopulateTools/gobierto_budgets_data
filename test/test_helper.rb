# frozen_string_literal: true

ENV["ELASTICSEARCH_URL"] ||= "http://localhost:9200"

require "minitest/autorun"
require "active_record"
require_relative "../lib/gobierto_budgets_data"
require_relative "support/budgets_database"
require_relative "support/search_engine_indices"
