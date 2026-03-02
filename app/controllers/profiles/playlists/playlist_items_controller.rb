# frozen_string_literal: true

# PlaylistItems controller
module Profiles
  module Playlists
    # Profiles playlist_items controller
    # rubocop:disable Metrics/ClassLength
    class PlaylistItemsController < BaseController
      before_action :check_current_user_playlist, only: %i[new create edit update destroy reorder]
      before_action :playlist_item, only: %i[edit update destroy]

      def new
        order = (@playlist.playlist_items&.order(:order)&.last&.order || 0) + 1
        @playlist_item = @playlist.playlist_items.new(order:)
        @igdb_cache = @playlist_item.build_igdb_cache
      end

      def edit
        @igdb_cache = @playlist_item.igdb_cache || @playlist_item.build_igdb_cache
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength
      def create
        igdb_id = playlist_item_igdb_id
        if igdb_id.blank?
          @playlist_item = @playlist.playlist_items.new(order: parse_position(playlist_item_params[:order]) || 1)
          add_igdb_required_error(@playlist_item)
          render_create_errors and return
        end

        igdb_cache = nil
        igdb_cache = IgdbCache.get_by_igdb_id(igdb_id)
        desired_position = parse_position(playlist_item_params[:order])
        next_order = (@playlist.playlist_items.maximum(:order) || 0) + 1
        @playlist_item = @playlist.playlist_items.new(order: next_order, igdb_cache:)
        respond_to do |format|
          if igdb_cache.nil?
            add_igdb_not_found_error(@playlist_item)
            render_create_errors(format)
            next
          end

          if duplicate_igdb_in_playlist?(igdb_cache)
            add_igdb_duplicate_error(@playlist_item)
            render_create_errors(format)
            next
          end

          if @playlist_item.save
            PlaylistItem.move_to_position!(@playlist, @playlist_item.id, desired_position) if desired_position.present?
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            render_create_errors(format)
          end
        rescue ActiveRecord::RecordNotUnique
          add_igdb_duplicate_error(@playlist_item)
          render_create_errors(format)
        end
      end

      def update
        igdb_id = playlist_item_igdb_id
        if igdb_id.blank?
          add_igdb_required_error(@playlist_item)
          render_update_errors and return
        end

        igdb_cache = nil
        igdb_cache = IgdbCache.get_by_igdb_id(igdb_id)
        desired_position = parse_position(playlist_item_params[:order])
        respond_to do |format|
          if igdb_cache.nil?
            add_igdb_not_found_error(@playlist_item)
            render_update_errors(format)
            next
          end

          if duplicate_igdb_in_playlist?(igdb_cache, @playlist_item.id)
            add_igdb_duplicate_error(@playlist_item)
            render_update_errors(format)
            next
          end

          if @playlist_item.update(igdb_cache:)
            PlaylistItem.move_to_position!(@playlist, @playlist_item.id, desired_position) if desired_position.present?
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            render_update_errors(format)
          end
        rescue ActiveRecord::RecordNotUnique
          add_igdb_duplicate_error(@playlist_item)
          render_update_errors(format)
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength

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
        params.require(:playlist_item).permit(:order, igdb_cache: %i[igdb_id name])
      end

      def playlist_item_igdb_id
        params.dig(:playlist_item, :igdb_cache, :igdb_id) || params.dig(:igdb_cache, :igdb_id)
      end

      def parse_position(value)
        parsed = Integer(value, 10)
        parsed.positive? ? parsed : nil
      rescue ArgumentError, TypeError
        nil
      end

      def add_igdb_not_found_error(record)
        record.errors.add(:base, "IGDB ID not found.")
      end

      def add_igdb_duplicate_error(record)
        record.errors.add(:base, "IGDB ID is already added to this playlist.")
      end

      def add_igdb_required_error(record)
        record.errors.add(:base, "IGDB ID must exist.")
      end

      def duplicate_igdb_in_playlist?(igdb_cache, except_id = nil)
        return false if igdb_cache.nil?

        scope = @playlist.playlist_items.where(igdb_cache_id: igdb_cache.id)
        scope = scope.where.not(id: except_id) if except_id.present?
        scope.exists?
      end

      def render_create_errors(format = nil)
        if format
          format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_item_errors", partial: "playlist_item_errors") }
        else
          render turbo_stream: turbo_stream.replace("playlist_item_errors", partial: "playlist_item_errors")
        end
      end

      def render_update_errors(format = nil)
        if format
          format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_item_errors", partial: "playlist_item_errors") }
        else
          render turbo_stream: turbo_stream.replace("playlist_item_errors", partial: "playlist_item_errors")
        end
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
