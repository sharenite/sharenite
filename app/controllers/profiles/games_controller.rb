# frozen_string_literal: true

# Games controller
module Profiles
  # Profiles games controller
  class GamesController < BaseController # rubocop:disable Metrics/ClassLength
    NONE_FILTER_VALUE = "__none__"
    SORT_ORDERS = {
      "name_asc" => { name: :asc },
      "name_desc" => { name: :desc },
      "last_activity_asc" => { last_activity: :asc },
      "playtime_asc" => { playtime: :asc },
      "playtime_desc" => { playtime: :desc },
      "play_count_asc" => { play_count: :asc },
      "play_count_desc" => { play_count: :desc }
    }.freeze
    SORT_SQL_ORDERS = {
      "source_asc" => "(SELECT LOWER(sources.name) FROM sources WHERE sources.id = games.source_id) ASC NULLS LAST, LOWER(games.name) ASC",
      "source_desc" => "(SELECT LOWER(sources.name) FROM sources WHERE sources.id = games.source_id) DESC NULLS LAST, LOWER(games.name) ASC",
      "status_asc" => "(SELECT LOWER(completion_statuses.name) FROM completion_statuses WHERE completion_statuses.id = games.completion_status_id) ASC NULLS LAST, LOWER(games.name) ASC",
      "status_desc" => "(SELECT LOWER(completion_statuses.name) FROM completion_statuses WHERE completion_statuses.id = games.completion_status_id) DESC NULLS LAST, LOWER(games.name) ASC"
    }.freeze

    before_action :check_current_user_profile, only: %i[edit update destroy]
    before_action :check_game_library_access_profile, only: %i[index show]
    before_action :game, only: %i[show edit update destroy]
    skip_before_action :check_general_access_profile, only: %i[index show]

    def index
      @can_view_gaming_activity = @profile.gaming_activity_visible_to?(current_user)
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
      respond_to do |format|
        if update_game_record
          format.turbo_stream { redirect_to profile_game_path(@profile, @game) }
        else
          format.turbo_stream { render turbo_stream: turbo_stream.replace("profile_errors", partial: "game_errors") }
        end
      end
    end

    def destroy
    end

    private

    def check_game_library_access_profile
      set_profile
      return if @profile.game_library_visible_to?(current_user)

      redirect_to_profile_when_game_library_hidden
    rescue ActiveRecord::RecordNotFound
      redirect_to_profiles_with_notice
    end

    def game_library_friend?
      return false unless current_user

      accepted_friendship_with_profile_user?
    end

    def set_sync_jobs
      return if @current_user.nil? || @profile != @current_user.profile

      @sync_jobs = @profile.user.sync_jobs.active.order(:created_at)
      @failed_sync_jobs = @profile.user.sync_jobs.recent_failures.limit(3)
    end

    def game
      set_profile if @profile.blank?
      @game = visible_games_scope.find_by(id: params[:id])
      @game ||= redirect_to_games_with_notice # defined in app controller
    rescue ActiveRecord::RecordNotFound
      redirect_to_games_with_notice
    end

    def filter_games
      search_query = params[:search_query].to_s.strip
      @games = @games.filter_by_name(search_query) if search_query.present?
      apply_relational_filters
      apply_tags_filter
      apply_categories_filter
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

    def apply_categories_filter
      category_ids = selected_filter_ids(:category_ids)
      include_none = filter_includes_none?(:category_ids)
      return if category_ids.blank? && !include_none

      clauses = []
      values = []

      if category_ids.present?
        clauses << "EXISTS (SELECT 1 FROM categories_games cg WHERE cg.game_id = games.id AND cg.category_id IN (?))"
        values << category_ids
      end
      clauses << "NOT EXISTS (SELECT 1 FROM categories_games cg WHERE cg.game_id = games.id)" if include_none

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
      return unless @can_view_gaming_activity

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
      return unless @can_view_gaming_activity

      from_date = parse_date_param(:last_activity_from)
      to_date = parse_date_param(:last_activity_to)
      return if from_date.blank? && to_date.blank?

      @games = @games.where("last_activity >= ?", from_date.beginning_of_day) if from_date.present?
      @games = @games.where("last_activity <= ?", to_date.end_of_day) if to_date.present?
    end

    def sort_games
      sort_key = effective_sort_key
      @games = if SORT_ORDERS.key?(sort_key)
                 @games.order(SORT_ORDERS.fetch(sort_key))
               elsif SORT_SQL_ORDERS.key?(sort_key)
                 @games.order(Arel.sql(SORT_SQL_ORDERS.fetch(sort_key)))
               else
                 @games.order_by_last_activity
               end
    end

    def set_search_options
      @source_options = belongs_to_search_options(:source, Source)
      @completion_status_options = belongs_to_search_options(:completion_status, CompletionStatus)
      @tag_options = collection_search_options(Tag)
      @category_options = collection_search_options(Category)
      @platform_options = collection_search_options(Platform)
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

    def redirect_to_profile_when_game_library_hidden
      if profile_visible_to_current_user?
        # rubocop:disable Rails/I18nLocaleTexts
        redirect_to profile_path(@profile), notice: "This profile's games are private."
        # rubocop:enable Rails/I18nLocaleTexts
      else
        redirect_to_profiles_with_notice
      end
    end

    def profile_visible_to_current_user?
      @profile.visible_to?(current_user)
    end

    def igdb_cache_update_requested?
      params.dig(:game, :igdb_cache)&.key?(:igdb_id)
    end

    def resolved_igdb_cache_from_params
      igdb_id = params.dig(:game, :igdb_cache, :igdb_id)
      return nil if igdb_id.blank?

      IgdbCache.get_by_igdb_id(igdb_id)
    end

    def igdb_cache_not_found?(igdb_cache)
      params.dig(:game, :igdb_cache, :igdb_id).present? && igdb_cache.nil?
    end

    def add_igdb_not_found_error(record, igdb_id)
      record.errors.add(:base, "IGDB entry was not found for ID #{igdb_id}.")
    end

    def update_game_record
      attributes = game_params.except(:igdb_cache)
      return @game.update(attributes) unless igdb_cache_update_requested?

      igdb_cache = resolved_igdb_cache_from_params
      return false if add_missing_igdb_error(igdb_cache)

      @game.update(attributes.merge(igdb_cache:))
    end

    def add_missing_igdb_error(igdb_cache)
      return false unless igdb_cache_not_found?(igdb_cache)

      add_igdb_not_found_error(@game, params.dig(:game, :igdb_cache, :igdb_id))
      true
    end

    def set_games
      @games = visible_games_scope.includes(:source, :completion_status, :tags, :categories, :platforms)
      filter_games
      sort_games
      @games_count = @games.count
      @games = @games.page params[:page]
    end

    def visible_games_scope
      scope = @profile.user.games
      return scope if profile_own?

      scope.where(private_override: false)
    end

    def belongs_to_search_options(association, klass)
      table_name = klass.table_name

      visible_games_scope.joins(association)
                         .distinct
                         .order("#{table_name}.name ASC")
                         .pluck("#{table_name}.name", "#{table_name}.id")
    end

    def collection_search_options(klass)
      klass.joins(:games)
           .merge(visible_games_scope)
           .distinct
           .order(:name)
           .pluck(:name, :id)
    end

    def effective_sort_key
      requested_sort = params[:sort].presence
      return requested_sort || "last_activity_desc" if @can_view_gaming_activity

      return "name_asc" if requested_sort.blank?
      return requested_sort unless requested_sort.start_with?("last_activity_", "playtime_", "play_count_")

      "name_asc"
    end

    def game_params
      params.require(:game).permit(:private_override, igdb_cache: [:igdb_id])
    end

    def redirect_to_games_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Game not found."
      # rubocop:enable all
      redirect_to profile_games_path
    end
  end
end
