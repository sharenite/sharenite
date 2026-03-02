# frozen_string_literal: true

# Playlists controller
module Profiles
  module Playlists
    # Profiles playlists controller
    class PlaylistsController < ::Profiles::BaseController
      before_action :playlist, only: %i[show edit update destroy]

      def index
        set_playlists
      end

      def show
        @owned_counts_by_igdb_cache_id = {}
        @owned_statuses_by_igdb_cache_id = {}
        set_playlist_overview
      end

      def new
        @playlist = @profile.user.playlists.new
      end

      def edit
      end

      def create
        @playlist = @profile.user.playlists.new(playlist_params)
        respond_to do |format|
          if @playlist.save
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_errors", partial: "playlist_errors") }
          end
        end
      end

      def update
        respond_to do |format|
          if @playlist.update(playlist_params)
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_errors", partial: "playlist_errors") }
          end
        end
      end

      def destroy
        @playlist.destroy!
        respond_to do |format|
          format.turbo_stream { redirect_to profile_playlists_path(@profile, @playlist) }
        end
      rescue ActiveRecord::RecordNotDestroyed => e
        flash[:error] = "errors that prevented deletion: #{e.record.errors.full_messages}}"
      end

      private

      def playlist
        @playlist = @profile.user.playlists.find_by(id: params[:id])
        @playlist ||= redirect_to_playlists_with_notice # defined in app controller
      end

      # rubocop:disable Metrics/AbcSize
      def set_playlists
        scope = @profile.user.playlists
                        .left_joins(:playlist_items)
                        .select("playlists.*, COUNT(playlist_items.id) AS items_count")
                        .group("playlists.id")

        name_query = params[:search_name].to_s.strip
        scope = scope.where("playlists.name ILIKE ?", "%#{name_query}%") if name_query.present?

        games_from = parse_items_count_param(:games_from)
        games_to = parse_items_count_param(:games_to)

        scope = scope.having("COUNT(playlist_items.id) >= ?", games_from) unless games_from.nil?
        scope = scope.having("COUNT(playlist_items.id) <= ?", games_to) unless games_to.nil?

        @playlists = scope.order("LOWER(playlists.name) ASC").page(params[:page]).per(25)
      end

      def parse_items_count_param(key)
        value = params[key].to_s.strip
        return if value.blank?

        parsed = Integer(value, 10)
        parsed.negative? ? nil : parsed
      rescue ArgumentError
        nil
      end

      def playlist_params
        params.require(:playlist).permit(:name, :public)
      end

      def set_playlist_overview
        @playlist_items = @playlist.playlist_items.includes(:igdb_cache).order(:order)
        igdb_cache_ids = @playlist_items.filter_map(&:igdb_cache_id).uniq
        return if igdb_cache_ids.empty?

        owned_games = @profile.user.games
                            .includes(:completion_status)
                            .where(igdb_cache_id: igdb_cache_ids)

        @owned_counts_by_igdb_cache_id = owned_games.group(:igdb_cache_id).count

        @owned_statuses_by_igdb_cache_id = Hash.new { |hash, key| hash[key] = [] }
        owned_games.each do |game|
          status_name = game.completion_status&.name || "No status"
          statuses = @owned_statuses_by_igdb_cache_id[game.igdb_cache_id]
          statuses << status_name unless statuses.include?(status_name)
        end
      end
      # rubocop:enable Metrics/AbcSize

      def redirect_to_playlists_with_notice
        # rubocop:disable Rails/I18nLocaleTexts
        flash[:notice] = "Playlist not found."
        # rubocop:enable all
        redirect_to profile_playlists_path
      end
    end
  end
end
