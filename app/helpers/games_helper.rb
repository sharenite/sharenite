# frozen_string_literal: true

# Games helper
module GamesHelper
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
