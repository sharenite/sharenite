# frozen_string_literal: true

# Games controller
module Profiles
  # Profiles games controller
  class GamesController < BaseController # rubocop:disable Metrics/ClassLength
    NONE_FILTER_VALUE = "__none__"

    before_action :game, only: %i[show edit update destroy]

    def index
      set_games
      set_sync_jobs
      set_search_options

      if turbo_frame_request?
        render partial: "games", locals: { games: @games }
      else
        render :index
      end
    end

    def show
    end

    def edit
      @igdb_cache = @game.igdb_cache || @game.build_igdb_cache
    end

    def update
      igdb_id = params[:game][:igdb_cache][:igdb_id]
      igdb_cache = nil
      igdb_cache = IgdbCache.get_by_igdb_id(igdb_id) if igdb_id.present?
      respond_to do |format|
        if @game.update(igdb_cache:)
          format.turbo_stream { redirect_to profile_game_path(@profile, @game) }
        else
          format.turbo_stream { render turbo_stream: turbo_stream.replace("game_errors", partial: "game_errors") }
        end
      end
    end

    def destroy
    end

    private

    def set_sync_jobs
      @sync_jobs = @profile.user.sync_jobs.active.order(:created_at) if !@current_user.nil? && @profile == @current_user.profile
    end

    def game
      @game = @profile.user.games.find_by(id: params[:id])
      @game ||= redirect_to_games_with_notice # defined in app controller
    end

    def filter_games
      search_query = params[:search_query].to_s.strip
      @games = @games.filter_by_name(search_query) if search_query.present?
      apply_relational_filters
      apply_tags_filter
      apply_platforms_filter
      apply_flag_filters
      apply_activity_filters
      apply_notes_or_review_filter
      apply_last_activity_date_range
    end

    def apply_relational_filters
      apply_source_filter
      apply_completion_status_filter
    end

    def apply_source_filter
      apply_nullable_belongs_to_filter(:source_id, selected_filter_ids(:source_ids),
                                       include_none: filter_includes_none?(:source_ids))
    end

    def apply_completion_status_filter
      apply_nullable_belongs_to_filter(:completion_status_id, selected_filter_ids(:completion_status_ids),
                                       include_none: filter_includes_none?(:completion_status_ids))
    end

    def apply_nullable_belongs_to_filter(column, ids, include_none:)
      return if ids.blank? && !include_none

      column_name = column.to_s
      @games = if ids.present? && include_none
                 @games.where("#{column_name} IN (?) OR #{column_name} IS NULL", ids)
               elsif ids.present?
                 @games.where(column => ids)
               else
                 @games.where(column => nil)
               end
    end

    def apply_tags_filter
      tag_ids = selected_filter_ids(:tag_ids)
      include_none = filter_includes_none?(:tag_ids)
      return if tag_ids.blank? && !include_none

      clauses = []
      values = []

      if tag_ids.present?
        clauses << "EXISTS (SELECT 1 FROM games_tags gt WHERE gt.game_id = games.id AND gt.tag_id IN (?))"
        values << tag_ids
      end
      clauses << "NOT EXISTS (SELECT 1 FROM games_tags gt WHERE gt.game_id = games.id)" if include_none

      @games = @games.where(clauses.join(" OR "), *values)
    end

    def apply_platforms_filter
      platform_ids = selected_filter_ids(:platform_ids)
      include_none = filter_includes_none?(:platform_ids)
      return if platform_ids.blank? && !include_none

      clauses = []
      values = []

      if platform_ids.present?
        clauses << "EXISTS (SELECT 1 FROM games_platforms gp WHERE gp.game_id = games.id AND gp.platform_id IN (?))"
        values << platform_ids
      end
      clauses << "NOT EXISTS (SELECT 1 FROM games_platforms gp WHERE gp.game_id = games.id)" if include_none

      @games = @games.where(clauses.join(" OR "), *values)
    end

    def apply_flag_filters
      @games = @games.where(favorite: true) if params[:favorite] == "1"
      @games = @games.where(is_installed: true) if params[:installed] == "1"
    end

    def apply_activity_filters
      @games = case params[:activity_state]
               when "played"
                 @games.where.not(last_activity: nil)
               when "unplayed"
                 @games.where(last_activity: nil)
               else
                 @games
               end
    end

    def apply_notes_or_review_filter
      return unless params[:notes_or_review] == "1"

      @games = @games.where("COALESCE(TRIM(notes), '') <> '' OR user_score IS NOT NULL")
    end

    def apply_last_activity_date_range
      from_date = parse_date_param(:last_activity_from)
      to_date = parse_date_param(:last_activity_to)
      return if from_date.blank? && to_date.blank?

      @games = @games.where("last_activity >= ?", from_date.beginning_of_day) if from_date.present?
      @games = @games.where("last_activity <= ?", to_date.end_of_day) if to_date.present?
    end

    def sort_games
      @games = case params[:sort]
               when "name_asc"
                 @games.order(name: :asc)
               when "name_desc"
                 @games.order(name: :desc)
               when "playtime_desc"
                 @games.order(playtime: :desc)
               when "play_count_desc"
                 @games.order(play_count: :desc)
               else
                 @games.order_by_last_activity
               end
    end

    def set_search_options
      @source_options = @profile.user.sources.order(:name).pluck(:name, :id)
      @completion_status_options = @profile.user.completion_statuses.order(:name).pluck(:name, :id)
      @tag_options = @profile.user.tags.order(:name).pluck(:name, :id)
      @platform_options = @profile.user.platforms.order(:name).pluck(:name, :id)
    end

    def selected_filter_ids(key)
      Array(params[key]).compact_blank.reject { |value| value == NONE_FILTER_VALUE }
    end

    def filter_includes_none?(key)
      Array(params[key]).include?(NONE_FILTER_VALUE)
    end

    def parse_date_param(key)
      value = params[key].to_s
      return if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def set_games
      @games = @profile.user.games
      filter_games
      sort_games
      @games = @games.distinct
      @games_count = @games.count
      @games = @games.page params[:page]
    end

    def game_params
      params.require(:game).permit(igdb_cache: [:igdb_id])
    end

    def redirect_to_games_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Game not found."
      # rubocop:enable all
      redirect_to profile_games_path
    end
  end
end
