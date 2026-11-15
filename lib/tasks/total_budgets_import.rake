namespace :gobierto_budgets_data do
  namespace :total_budget do
    desc "Import total budgets. Example rake total_budget:import['budgets-execution',2014] place_id=28079 province_id=3 autonomous_region_id=5"
    task :import, [:index, :year, :place_type] => :environment do |t, args|
      index = args[:index] if GobiertoBudgetsData::GobiertoBudgets::ALL_INDEXES.include?(args[:index])
      raise "Invalid index #{args[:index]}" if index.blank?

      if m = args[:year].match(/\A\d{4}\z/)
        year = m[0].to_i
      end

      places = GobiertoBudgetsData::GobiertoBudgets::PlaceDecorator.collection(args[:place_type].presence || :ine, ENV)

      GobiertoBudgetsData::GobiertoBudgets::PlacesTotalBudgetsImporter.new(
        client: GobiertoBudgets::SearchEngine.client,
        index:,
        year:,
        places:
      ).import
    end
  end
end
