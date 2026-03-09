# frozen_string_literal: true

json.array! @games, partial: "profiles/games/game", as: :game
