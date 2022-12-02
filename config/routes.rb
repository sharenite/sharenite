# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq_unique_jobs/web"

Rails.application.routes.draw do
  resources :profiles, controller: "profiles/profiles" do
    resources :games, controller: "profiles/games" do
      collection { post :search }
    end
    resources :friends, controller: "profiles/friends", only: :index
    get "friends/invite", to: "profiles/friends#invite", as: :invite_friend
    get "friends/:id/accept", to: "profiles/friends#accept", as: :accept_friend
    get "friends/:id/decline", to: "profiles/friends#decline", as: :decline_friend
    get "friends/:id/cancel", to: "profiles/friends#cancel", as: :cancel_friend
  end
  root "static_pages#landing_page"

  devise_for :users
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  mount API::Base, at: "/"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  authenticate :admin_user, ->(admin_user) { admin_user.present? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  get "static_pages/dashboard"
end
