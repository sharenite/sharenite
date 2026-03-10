# frozen_string_literal: true

module Profiles
  # Shared playlist loading and visibility helpers for profile playlist pages.
  module PlaylistAccess
    private

    def playlist
      @playlist = @profile.user.playlists.find_by(id: params[:id])
      return redirect_to_playlists_with_notice unless @playlist
      return unless playlist_hidden_for_viewer?

      redirect_when_playlist_hidden
    end

    def set_playlists
      scope = playlists_scope_with_counts

      name_query = params[:search_name].to_s.strip
      scope = scope.where("playlists.name ILIKE ?", "%#{name_query}%") if name_query.present?

      games_from = parse_items_count_param(:games_from)
      games_to = parse_items_count_param(:games_to)
      scope = apply_playlist_item_filters(scope, games_from:, games_to:)

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

    def set_playlist_overview
      @playlist_items = @playlist.playlist_items.includes(:igdb_cache).order(:order)
      igdb_cache_ids = @playlist_items.filter_map(&:igdb_cache_id).uniq
      return if igdb_cache_ids.empty?

      assign_owned_playlist_game_data(igdb_cache_ids)
    end

    def playlist_hidden_for_viewer?
      !profile_own? && (!@profile.playlists_visible_to?(current_user) || !@playlist.public?)
    end

    def redirect_when_playlist_hidden
      return redirect_to_profile_when_playlist_library_hidden unless @profile.playlists_visible_to?(current_user)

      redirect_to_playlists_with_notice
    end

    def playlists_scope_with_counts
      scope = @profile.user.playlists
      scope = scope.where(public: true) unless profile_own?
      scope.left_joins(:playlist_items)
           .select("playlists.*, COUNT(playlist_items.id) AS items_count")
           .group("playlists.id")
    end

    def apply_playlist_item_filters(scope, games_from:, games_to:)
      scope = scope.having("COUNT(playlist_items.id) >= ?", games_from) unless games_from.nil?
      scope = scope.having("COUNT(playlist_items.id) <= ?", games_to) unless games_to.nil?
      scope
    end

    def assign_owned_playlist_game_data(igdb_cache_ids)
      owned_games = owned_playlist_games(igdb_cache_ids)
      @owned_counts_by_igdb_cache_id = owned_games.group(:igdb_cache_id).count
      @owned_statuses_by_igdb_cache_id = Hash.new { |hash, key| hash[key] = [] }
      append_owned_playlist_statuses(owned_games)
    end

    def owned_playlist_games(igdb_cache_ids)
      @profile.user.games
              .includes(:completion_status)
              .where(igdb_cache_id: igdb_cache_ids)
    end

    def append_owned_playlist_statuses(owned_games)
      owned_games.each do |game|
        status_name = game.completion_status&.name || "No status"
        statuses = @owned_statuses_by_igdb_cache_id[game.igdb_cache_id]
        statuses << status_name unless statuses.include?(status_name)
      end
    end
  end
end
