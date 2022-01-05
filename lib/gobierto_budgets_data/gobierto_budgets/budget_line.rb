# frozen_string_literal: true

module GobiertoBudgetsData
  module GobiertoBudgets
    class BudgetLine
      def self.all(options)
        area_name = options[:area_name]
        updated_forecast = options.delete(:updated_forecast) || false

        terms = [
          { missing: { field: "functional_code"} },
          { missing: { field: "custom_code"} }
        ]

        permitted_terms.each do |term_key|
          terms << build_term(term_key, options[term_key]) if options[term_key]
        end

        query = {
          query: {
            filtered: {
              filter: {
                bool: {
                  must: terms
                }
              }
            }
          },
          aggs: {
            total_budget: { sum: { field: "amount" } },
            total_budget_per_inhabitant: { sum: { field: "amount_per_inhabitant" } },
          },
          size: 10_000
        }

        index = if updated_forecast
                  GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_FORECAST_UPDATED
                else
                  default_index
                end

        response = SearchEngine.client.search(index: index, type: area_name, body: query)

        if updated_forecast && response["hits"]["hits"].empty?
          response = SearchEngine.client.search(index: default_index, type: area_name, body: query)
        end

        response["hits"]["hits"].map{ |h| h["_source"] }.map do |row|
          BudgetLinePresenter.new(row.merge(
            area_name: area_name,
            total: response["aggregations"]["total_budget"]["value"],
            total_budget_per_inhabitant: response["aggregations"]["total_budget_per_inhabitant"]["value"]
          ))
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        []
      end

      def self.build_term(term_key, term_value)
        { term: { term_key => term_value } }
      end

      def self.permitted_terms
        %i[kind organization_id level]
      end

      def self.default_index
        GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_FORECAST
      end

      attr_reader :code_object, :id, :code, :amount

      def initialize(attributes)
        @organization_id = attributes[:organization_id]
        @year = attributes[:year].to_i
        @code = attributes[:code]
        @kind = attributes[:kind]
        # The index could be replaced by the table name when we migrate from ElasticSearch to PostgreSQL
        @index = attributes[:index]
        @area_name = attributes[:area_name]
        @amount = attributes[:amount]
        # Population can be provided as argument for performance reasons
        @population = attributes[:population]
        @custom_code = attributes[:custom_code]
        @functional_code = attributes[:functional_code]

        @code_object = if @area_name == CUSTOM_AREA_NAME
                         # In custom categories the code is composed of custom + economic + functional
                         # but the custom categories imported in the database use just the custom code (left side)
                         custom_code = @code.split("-").first
                         BudgetLineCode.new(custom_code, { organization_id: @organization_id, area_name: @area_name, kind: @kind })
                       else
                         BudgetLineCode.new(@code)
                       end

        # The id might change a bit when the budget line belongs to
        # economic aggregations (changes implemented in area_code method)
        @id = [
          @organization_id,
          @year,
          area_code,
          @kind
        ].join("/")
      end

      def amount=(value)
        @amount = value.to_f.round(2)
      end

      def data
        {
          index: {
            _index: @index,
            _id: @id,
            _type: type,
            data: budget_line_data
          }
        }
      end

      def area_code
        case @area_name
        when GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME
          [row.field("custom_code"), @code, "c"].join("/")
        when GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME
          [row.field("functional_code"), @code, "f"].join("/")
        else
          @code
        end
      end

      private

      def budget_line_data
        {
          "organization_id": @organization_id,
          "ine_code": ine_code,
          "province_id": province_id,
          "autonomy_id": autonomy_id,
          "year": @year,
          "population": population,
          "amount": @amount,
          "code": @code,
          "level": @code_object.level,
          "kind": @kind,
          "amount_per_inhabitant": amount_per_inhabitant,
          "parent_code": @code_object.parent_code
        }.merge(economic_code_data)
      end

      def place
        @place ||= ::INE::Places::Place.find(@organization_id)
      end

      def ine_code
        @ine_code ||= place&.id.try(:to_i)
      end

      def province_id
        place&.province&.id.try(:to_i)
      end

      def autonomy_id
        place&.province&.autonomous_region&.id.try(:to_i)
      end

      def population
        return 100000
        @population ||= GobiertoBudgetsData::GobiertoBudgets::Population.get(ine_code, @year)
      end

      def amount_per_inhabitant
        return 0.0 if population.blank? || population.zero?

        (@amount / population).round(2)
      end

      def type
        case @area_name
        when GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME
          GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
        when GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME
          GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_AREA_NAME
        else
          @area_name
        end
      end

      def economic_code_data
        case @area_name
        when GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_CUSTOM_AREA_NAME
          { "custom_code": @custom_code }
        when GobiertoBudgetsData::GobiertoBudgets::ECONOMIC_FUNCTIONAL_AREA_NAME
          { "functional_code": @functional_code }
        else
          {}
        end
      end
    end
  end
end
