# frozen_string_literal: true

# PlaylistItems controller
module Profiles
  module Playlists
    # Profiles playlist_items controller
    class PlaylistItemsController < BaseController
      before_action :playlist_item, only: %i[edit update destroy]
      before_action :check_current_user_playlist, only: :reorder

      def new
        order = (@playlist.playlist_items&.order(:order)&.last&.order || 0) + 1
        @playlist_item = @playlist.playlist_items.new(order:)
        @igdb_cache = @playlist_item.build_igdb_cache
      end

      def edit
        @igdb_cache = @playlist_item.igdb_cache || @playlist_item.build_igdb_cache
      end

      # rubocop:disable Metrics/AbcSize
      def create
        igdb_id = params[:playlist_item][:igdb_cache][:igdb_id]
        igdb_cache = nil
        igdb_cache = IgdbCache.get_by_igdb_id(igdb_id) if igdb_id.present?
        desired_position = parse_position(playlist_item_params[:order])
        next_order = (@playlist.playlist_items.maximum(:order) || 0) + 1
        @playlist_item = @playlist.playlist_items.new(order: next_order, igdb_cache:)
        respond_to do |format|
          if @playlist_item.save
            PlaylistItem.move_to_position!(@playlist, @playlist_item.id, desired_position) if desired_position.present?
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_item_errors", partial: "playlist_item_errors") }
          end
        end
      end

      def update
        igdb_id = params[:playlist_item][:igdb_cache][:igdb_id]
        igdb_cache = nil
        igdb_cache = IgdbCache.get_by_igdb_id(igdb_id) if igdb_id.present?
        desired_position = parse_position(playlist_item_params[:order])
        respond_to do |format|
          if @playlist_item.update(igdb_cache:)
            PlaylistItem.move_to_position!(@playlist, @playlist_item.id, desired_position) if desired_position.present?
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_item_errors", partial: "playlist_item_errors") }
          end
        end
      end
      # rubocop:enable all

      def destroy
        @playlist_item.destroy!
        respond_to do |format|
          format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
        end
      rescue ActiveRecord::RecordNotDestroyed => e
        flash[:error] = "errors that prevented deletion: #{e.record.errors.full_messages}}"
      end

      def reorder
        PlaylistItem.reorder_for_playlist!(@playlist, params[:ordered_ids])
        render json: { ok: true }
      rescue StandardError => e
        Rails.logger.error(
          "Failed to reorder playlist items for playlist #{@playlist&.id}: #{e.class}: #{e.message}"
        )
        render json: { error: "Unable to reorder playlist items." }, status: :unprocessable_entity
      end

      private

      def playlist_item
        check_current_user_playlist if @playlist.blank?
        return if performed?

        @playlist_item = @playlist.playlist_items.find_by(id: params[:id])
        @playlist_item ||= redirect_to_playlist_with_notice
      end

      def set_playlist_items
        @playlist_items = @profile.user.playlist_items
        @playlist_items = @playlist_items.page params[:page]
      end

      def playlist_item_params
        params.require(:playlist_item).permit(:order, igdb_cache: :igdb_id)
      end

      def parse_position(value)
        parsed = Integer(value, 10)
        parsed.positive? ? parsed : nil
      rescue ArgumentError, TypeError
        nil
      end

      def redirect_to_playlist_with_notice
        # rubocop:disable Rails/I18nLocaleTexts
        flash[:notice] = "PlaylistItem not found."
        # rubocop:enable all
        if @playlist.present?
          redirect_to profile_playlist_path(@profile, @playlist)
        else
          redirect_to profile_playlists_path(@profile)
        end
      end
    end
  end
end
