# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaylistItem do
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
