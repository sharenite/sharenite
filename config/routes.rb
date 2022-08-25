# frozen_string_literal: true

Rails.application.routes.draw do
  resources :games
  root 'static_pages#landing_page'

  devise_for :users
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  mount API::Base, at: '/'
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  get 'static_pages/dashboard'
end
