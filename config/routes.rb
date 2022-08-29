# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  resources :games do
    collection do
      post :search
    end
  end
  root "static_pages#landing_page"

  devise_for :users
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  mount API::Base, at: "/"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  authenticate :admin_user, ->(admin_user) { admin_user.present? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  get "static_pages/dashboard"
end
