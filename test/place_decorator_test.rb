# frozen_string_literal: true

require "test_helper"

class PlaceDecoratorTest < Minitest::Test
  PlaceDecorator = GobiertoBudgetsData::GobiertoBudgets::PlaceDecorator

  def madrid
    PlaceDecorator.find("28079")
  end

  def test_matches_without_filters
    assert madrid.matches?({})
  end

  def test_matches_place_id
    assert madrid.matches?("place_id" => "28079")
    refute madrid.matches?("place_id" => "8019")
  end

  def test_matches_province_and_autonomous_region
    assert madrid.matches?("province_id" => "28", "autonomous_region_id" => "13")
    refute madrid.matches?("province_id" => "8")
    refute madrid.matches?("autonomous_region_id" => "9")
  end

  def test_matches_custom_place_id
    deputation = PlaceDecorator.collection(:deputation_eu).first

    assert deputation.matches?("custom_place_id" => "deputation_eu")
    refute madrid.matches?("custom_place_id" => "deputation_eu")
  end

  def test_filtered_collection
    places = PlaceDecorator.collection(:ine, "province_id" => "28")

    assert_includes places.map(&:id), "28079"
    assert places.all? { |place| place.attributes["province_id"] == 28 }
  end
end
