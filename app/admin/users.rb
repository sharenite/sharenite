# frozen_string_literal: true

ActiveAdmin.register User do
  menu priority: 2

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  # permit_params :email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at,
  #               :sign_in_count, :current_sign_in_at, :last_sign_in_at, :current_sign_in_ip, :last_sign_in_ip, :confirmation_token, :confirmed_at, :confirmation_sent_at, :unconfirmed_email
  #
  # or
  #
  # permit_params do
  # permitted = %i[email encrypted_password reset_password_token reset_password_sent_at remember_created_at
  #                sign_in_count current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip confirmation_token confirmed_at confirmation_sent_at unconfirmed_email]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  index do
    id_column
    column :email
    column :games_count do |user|
      link_to user.games.count, admin_user_games_path(user) 
    end
    column :current_sign_in_at
    column :current_sign_in_ip
    column :last_sign_in_at
    column :last_sign_in_ip
    column :created_at
    column :updated_at
    actions
  end

  filter :email

  sidebar "User Details", only: [:show, :edit] do
    ul do
      li link_to "Games", admin_user_games_path(resource)
    end
  end
end
