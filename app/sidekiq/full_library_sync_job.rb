# frozen_string_literal: true

# Job that performs a full library sync asynchornously
# rubocop:disable Metrics:ClassLength
class FullLibrarySyncJob
  include Sidekiq::Job

  def variables(args)
    @games = args[0]
    @user = User.find(args[1])
    @sync_job = SyncJob.find(args[2])
  end

  def perform(*args)
    variables(args)
    start_job
    synchronise_games
    finish_job
  end

  private

  def start_job
    @sync_job.status_running!
  end

  def finish_job
    @sync_job.status_finished!
  end

  def synchronise_games
    @user
      .games
      .where.not(
        playnite_id: @games.map { |playnite_game| playnite_game["id"] }
      )
      .destroy_all

    @games.each do |playnite_game|
      sharenite_game =
        @user.games.create_or_find_by!(playnite_id: playnite_game["id"])

      sharenite_game.update!(
        playnite_game.slice(
          "added",
          "community_score",
          "critic_score",
          "description",
          "favorite",
          "game_id",
          "game_started_script",
          "hidden",
          "include_library_plugin_action",
          "install_directory",
          "is_custom_game",
          "is_installed",
          "is_installing",
          "is_launching",
          "is_running",
          "is_uninstalling",
          "last_activity",
          "manual",
          "modified",
          "name",
          "notes",
          "play_count",
          "playnite_id",
          "playtime",
          "plugin_id",
          "post_script",
          "pre_script",
          "release_date",
          "sorting_name",
          "use_global_game_started_script",
          "use_global_post_script",
          "use_global_pre_script",
          "user_score",
          "version"
        ).merge(
          "tags" => tags(playnite_game),
          "categories" => categories(playnite_game),
          "platforms" => platforms(playnite_game)
        )
      )
    end
  end

  def tags(playnite_game)
    tags = []
    playnite_game["tags"]&.each do |playnite_tag|
      sharenite_tag =
        @user.tags.create_or_find_by!(playnite_id: playnite_tag["id"])
      sharenite_tag.update!(name: playnite_tag["name"])
      tags << sharenite_tag
    end
    tags
  end

  def categories(playnite_game)
    categories = []
    playnite_game["categories"]&.each do |playnite_category|
      sharenite_category =
        @user.categories.create_or_find_by!(
          playnite_id: playnite_category["id"]
        )
      sharenite_category.update!(name: playnite_category["name"])
      categories << sharenite_category
    end
    categories
  end

  def platforms(playnite_game)
    platforms = []
    playnite_game["platforms"]&.each do |playnite_platform|
      sharenite_platform =
        @user.platforms.create_or_find_by!(playnite_id: playnite_platform["id"])
      sharenite_platform.update!(
        name: playnite_platform["name"],
        specification_id: playnite_platform["specification_id"]
      )
      platforms << sharenite_platform
    end
    platforms
  end
end
# rubocop:enable Metrics:ClassLength
