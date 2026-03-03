# frozen_string_literal: true

# Job that performs a full library sync asynchornously
# rubocop:disable Metrics:ClassLength
class FullLibrarySyncService
  MissingFullSyncIdsError = Class.new(StandardError)
  InvalidFullSyncIdsError = Class.new(StandardError)

m  def initialize(games, user, sync_job, sync_batch_id: nil, chunk_index: 0, total_chunks: 1)
    @games = games
    @user = user
    @sync_job = sync_job
    @sync_batch_id = sync_batch_id
    @chunk_index = chunk_index.to_i
    @total_chunks = total_chunks.to_i
  end

  def call
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
    @games.each do |playnite_game|
      sharenite_game = @user.games.find_or_create_by!(playnite_id: playnite_game["id"])

      sharenite_game.update!(
        playnite_game.slice(
          "added",
          "community_score",
          "critic_score",
          "description",
          "enable_system_hdr",
          "favorite",
          "game_id",
          "game_started_script",
          "hidden",
          "include_library_plugin_action",
          "install_directory",
          "install_size",
          "is_custom_game",
          "is_installed",
          "is_installing",
          "is_launching",
          "is_running",
          "is_uninstalling",
          "last_activity",
          "last_size_scan_date",
          "manual",
          "modified",
          "name",
          "notes",
          "override_install_state",
          "play_count",
          "playnite_id",
          "playtime",
          "plugin_id",
          "post_script",
          "pre_script",
          "recent_activity",
          "sorting_name",
          "use_global_game_started_script",
          "use_global_post_script",
          "use_global_pre_script",
          "user_score",
          "version"
        ).merge(
          "age_ratings" => properties(playnite_game, "age_ratings"),
          "categories" => properties(playnite_game, "categories"),
          "completion_status" => completion_status(playnite_game),
          "developers" => properties(playnite_game, "developers"),
          "features" => properties(playnite_game, "features"),
          "genres" => properties(playnite_game, "genres"),
          "links" => links(playnite_game, sharenite_game),
          "platforms" => properties(playnite_game, "platforms"),
          "publishers" => properties(playnite_game, "publishers"),
          "regions" => properties(playnite_game, "regions"),
          "release_date" => release_date(playnite_game),
          "roms" => roms(playnite_game, sharenite_game),
          "series" => properties(playnite_game, "series"),
          "source" => source(playnite_game),          
          "tags" => properties(playnite_game, "tags"),
        )
      )
    end

    delete_missing_games if final_chunk?
  end

  def delete_missing_games
    ids_to_keep = full_sync_ids
    @user.games.where.not(playnite_id: ids_to_keep).or(@user.games.where(playnite_id: nil)).destroy_all
    clear_full_sync_ids if @sync_batch_id.present?
  end

  def full_sync_ids
    return @games.pluck("id") if @sync_batch_id.blank?

    # rubocop:disable Style/GlobalVars
    raw_ids = $redis.get(full_sync_ids_redis_key)
    # rubocop:enable Style/GlobalVars
    raise MissingFullSyncIdsError, "Missing Redis full sync IDs for batch #{@sync_batch_id}" if raw_ids.blank?

    parsed_ids = JSON.parse(raw_ids)
    raise InvalidFullSyncIdsError, "Invalid full sync IDs payload for batch #{@sync_batch_id}: expected Array" unless parsed_ids.is_a?(Array)

    current_chunk_ids = @games.pluck("id")
    unless current_chunk_ids.all? { |id| parsed_ids.include?(id) }
      raise InvalidFullSyncIdsError,
            "Full sync IDs for batch #{@sync_batch_id} do not include all current chunk IDs"
    end

    parsed_ids
  rescue JSON::ParserError => e
    raise InvalidFullSyncIdsError, "Invalid JSON for full sync IDs batch #{@sync_batch_id}: #{e.message}"
  end

  def clear_full_sync_ids
    # rubocop:disable Style/GlobalVars
    $redis.del(full_sync_ids_redis_key)
    # rubocop:enable Style/GlobalVars
  end

  def full_sync_ids_redis_key
    "full_sync_ids:#{@sync_batch_id}"
  end

  def final_chunk?
    @chunk_index >= @total_chunks - 1
  end

  def properties(playnite_game, property_name)
    properties = []
    playnite_game[property_name]&.each do |playnite_property|
      sharenite_property = @user.send(property_name).find_or_create_by!(playnite_id: playnite_property["id"])
      sharenite_property.update!(name: playnite_property["name"])
      properties << sharenite_property
    end
    properties
  end
 
  def links(playnite_game, sharenite_game)
    links = []
    playnite_game["links"]&.each do |playnite_link|
      sharenite_link = sharenite_game.links.find_or_create_by!(name: playnite_link["name"])
      sharenite_link.update!(url: playnite_link["url"])
      links << sharenite_link
    end
    links
  end

  def roms(playnite_game, sharenite_game)
    roms = []
    playnite_game["roms"]&.each do |playnite_rom|
      sharenite_rom = sharenite_game.roms.find_or_create_by!(name: playnite_rom["name"])
      sharenite_rom.update!(path: playnite_rom["path"])
      roms << sharenite_rom
    end
    roms
  end

  def release_date(playnite_game)
     playnite_game.dig("release_date", "ReleaseDate")
  end

  def completion_status(playnite_game)
    return nil if playnite_game["completion_status"].nil?
    sharenite_completion_status = @user.completion_statuses.find_or_create_by!(playnite_id: playnite_game["completion_status"]["id"])
    sharenite_completion_status.update!(name: playnite_game["completion_status"]["name"])
    sharenite_completion_status
  end

  def source(playnite_game)
    return nil if playnite_game["source"].nil?
    sharenite_source = @user.sources.find_or_create_by!(playnite_id: playnite_game["source"]["id"])
    sharenite_source.update!(name: playnite_game["source"]["name"])
    sharenite_source
  end
end
# rubocop:enable Metrics:ClassLength
