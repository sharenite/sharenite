# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaylistItem do
  describe "validations" do
    it "enforces unique igdb_cache per playlist" do
      playlist = create(:playlist)
      igdb_cache = create(:igdb_cache)
      create(:playlist_item, playlist:, igdb_cache:, order: 1)

      duplicate = build(:playlist_item, playlist:, igdb_cache:, order: 2)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:igdb_cache_id]).to include("has already been taken")
    end

    it "enforces unique order per playlist" do
      playlist = create(:playlist)
      create(:playlist_item, playlist:, order: 1)

      duplicate_order = build(:playlist_item, playlist:, order: 1)

      expect(duplicate_order).not_to be_valid
      expect(duplicate_order.errors[:order]).to include("has already been taken")
    end
  end

  describe ".reorder_for_playlist!" do
    it "reorders deterministically using current order for omitted ids" do
      playlist = create(:playlist)
      first = create(:playlist_item, playlist:, order: 1)
      second = create(:playlist_item, playlist:, order: 2)
      third = create(:playlist_item, playlist:, order: 3)

      described_class.reorder_for_playlist!(playlist, [third.id])

      ordered_ids = playlist.playlist_items.order(:order).pluck(:id)
      expect(ordered_ids).to eq([third.id, first.id, second.id])
    end
  end

  describe ".move_to_position!" do
    it "moves a playlist item to the requested position and normalizes order" do
      playlist = create(:playlist)
      first = create(:playlist_item, playlist:, order: 1)
      second = create(:playlist_item, playlist:, order: 2)
      third = create(:playlist_item, playlist:, order: 3)

      described_class.move_to_position!(playlist, third.id, 1)

      ordered_ids = playlist.playlist_items.order(:order).pluck(:id)
      expect(ordered_ids).to eq([third.id, first.id, second.id])

      orders = playlist.playlist_items.order(:order).pluck(:order)
      expect(orders).to eq([1, 2, 3])
    end
  end
end
