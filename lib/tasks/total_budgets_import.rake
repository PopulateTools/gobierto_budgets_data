namespace :gobierto_budgets_data do
  namespace :total_budget do
    def get_data(index,place,year,kind,type=nil)
      type ||= (kind == 'G') ? 'functional' : 'economic'

      # total budget in a place
      query = {
        query: {
          bool: {
            must: {
              match_all: {}
            },
            filter: [
              {term: { type: type }},
              {term: { ine_code: place.attributes["place_id"] }},
              {term: { level: 1 }},
              {term: { kind: kind }},
              {term: { year: year }},
              {term: { organization_id: place.id.to_s }},
            ].select { |condition| condition.values.all? { |val| val.values.all?(&:present?) } },
            must_not: [
              {exists: { field: "functional_code" }},
              {exists: { field: "custom_code" }},
            ]
          }
        },
        aggs: {
          total_budget: { sum: { field: 'amount' } },
          total_budget_per_inhabitant: { sum: { field: 'amount_per_inhabitant' } },
        },
        size: 0
      }

      result = GobiertoBudgets::SearchEngine.client.search index: index, body: query
      return result['aggregations']['total_budget']['value'].round(2), result['aggregations']['total_budget_per_inhabitant']['value'].round(2)
    end

    def import_total_budget(year, index, kind, opts = {})
      places_key = opts.fetch(:place_type, :ine)
      places = GobiertoBudgetsData::GobiertoBudgets::PlaceDecorator.collection(places_key)

      places.each do |place|
        place.attributes.each do |key, value|
          next if ENV[key].present? && value != ENV[key].to_i
        end

        next if ENV["custom_place_id"].present? && place.custom_place_id != ENV["custom_place_id"]

        total_budget, total_budget_per_inhabitant = get_data(index, place, year, kind)
        if total_budget == 0.0 && kind == 'G'
          total_budget, total_budget_per_inhabitant = get_data(index, place, year, kind, 'economic')
        end

        data = {
          ine_code: place.attributes["place_id"],
          province_id: place.attributes["province_id"],
          autonomy_id: place.attributes["autonomous_region_id"],
          organization_id: place.id.to_s,
          year: year,
          kind: kind,
          amount: total_budget,
          amount_per_inhabitant: total_budget_per_inhabitant,
          type: GobiertoBudgetsData::GobiertoBudgets::TOTAL_BUDGET_TYPE
        }

        id = [place.id,year,kind, GobiertoBudgetsData::GobiertoBudgets::TOTAL_BUDGET_TYPE].join("/")
        GobiertoBudgets::SearchEngine.client.index index: index,  id: id, body: data
      end
    end

    desc "Import total budgets. Example rake total_budget:import['budgets-execution',2014] place_id=28079 province_id=3 autonomous_region_id=5"
    task :import, [:index, :year, :place_type] => :environment do |t, args|
      index = args[:index] if GobiertoBudgetsData::GobiertoBudgets::ALL_INDEXES.include?(args[:index])
      raise "Invalid index #{args[:index]}" if index.blank?

      if m = args[:year].match(/\A\d{4}\z/)
        year = m[0].to_i
      end

      opts = args.to_h.slice(:place_type)

      import_total_budget(year, index, GobiertoBudgetsData::GobiertoBudgets::EXPENSE, **opts)
      import_total_budget(year, index, GobiertoBudgetsData::GobiertoBudgets::INCOME , **opts)
    end
  end
end
