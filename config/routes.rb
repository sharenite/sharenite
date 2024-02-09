# frozen_string_literal: true

require "karafka/web"

Rails.application.routes.draw do
  authenticate :admin_user, ->(admin_user) { !admin_user.nil? } do
    mount Karafka::Web::App, at: "/karafka"
  end

  # rubocop:disable Metrics/BlockLength
  resources :profiles, controller: "profiles/profiles" do
    resources :games, controller: "profiles/games" do
      collection { post :search }
    end
    resources :friends, controller: "profiles/friends", only: :index
    resources :playlists, controller: "profiles/playlists/playlists" do
      resources :playlist_items, controller: "profiles/playlists/playlist_items", only: [:new, :create, :edit, :update, :destroy]
    end
    get "friends/invite", to: "profiles/friends#invite", as: :invite_friend
    get "friends/:id/accept", to: "profiles/friends#accept", as: :accept_friend
    get "friends/:id/decline", to: "profiles/friends#decline", as: :decline_friend
    get "friends/:id/cancel", to: "profiles/friends#cancel", as: :cancel_friend
  end
  # rubocop:enable all
  root "static_pages#landing_page"
  get "static_pages/dashboard"

  devise_for :users
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # This for some reason has to be last
  mount API::Base, at: "/"
end
