# frozen_string_literal: true

# Games helper
module GamesHelper
  SORT_OPTIONS = [
    ["Last Activity (Newest first)", "last_activity_desc"],
    ["Last Activity (Oldest first)", "last_activity_asc"],
    ["Title (A-Z)", "name_asc"],
    ["Title (Z-A)", "name_desc"],
    ["Source (A-Z)", "source_asc"],
    ["Source (Z-A)", "source_desc"],
    ["Status (A-Z)", "status_asc"],
    ["Status (Z-A)", "status_desc"],
    ["Playtime (Highest first)", "playtime_desc"],
    ["Playtime (Lowest first)", "playtime_asc"],
    ["Plays (Highest first)", "play_count_desc"],
    ["Plays (Lowest first)", "play_count_asc"]
  ].freeze
  ACTIVITY_SORT_VALUES = %w[
    last_activity_desc
    last_activity_asc
    playtime_desc
    playtime_asc
    play_count_desc
    play_count_asc
  ].freeze

  def games_sort_options(can_view_gaming_activity: true)
    return SORT_OPTIONS if can_view_gaming_activity

    SORT_OPTIONS.reject { |(_, value)| ACTIVITY_SORT_VALUES.include?(value) }
  end

  def games_sort_link(profile, label, current_sort, sort_keys)
    asc_key = sort_keys.fetch(:asc)
    desc_key = sort_keys.fetch(:desc)
    direction = games_sort_direction(current_sort, asc_key, desc_key)
    next_sort = direction == "asc" ? desc_key : asc_key
    indicator = games_sort_indicator(direction)

    link_to("#{label}#{indicator}", profile_games_path(profile, request.query_parameters.merge(sort: next_sort, page: nil)),
            class: "games-sort-link#{' active' if direction.present?}",
            data: { turbo_frame: "games", turbo_action: "replace" })
  end

  private

  def games_sort_direction(current_sort, asc_key, desc_key)
    return "asc" if current_sort == asc_key
    return "desc" if current_sort == desc_key

    nil
  end

  def games_sort_indicator(direction)
    { "asc" => " \u2191", "desc" => " \u2193", nil => "" }.fetch(direction)
  end
end
