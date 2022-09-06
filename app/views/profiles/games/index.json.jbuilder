# frozen_string_literal: true

json.array! @games, partial: 'games/game', as: :game
