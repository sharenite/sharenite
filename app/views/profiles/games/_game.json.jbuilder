# frozen_string_literal: true

json.extract! game, :id, :name, :user_id, :created_at, :updated_at
json.url profile_game_url(@profile, game, format: :json)
