# frozen_string_literal: true

ActiveAdmin.register Playlist do
  config.sort_order = "name"
  menu priority: 4

  belongs_to :user, optional: true
  includes :user, :playlist_items

  permit_params :name, :user_id, :private_override

  collection_action :user_options, method: :get do
    query = params[:q].to_s.strip
    users = User.order(:email)
    if query.present?
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
      users = users.where("users.email ILIKE ?", "%#{sanitized_query}%")
    else
      users = users.none
    end

    render json: users.limit(20).map { |user| { id: user.id, label: user.email } }
  end

  controller do
    before_action :normalize_playlist_user_param, only: %i[create update]

    private

    def normalize_playlist_user_param
      playlist_params = params[:playlist]
      return unless playlist_params.is_a?(ActionController::Parameters) || playlist_params.is_a?(Hash)
      return if playlist_params[:user_id].present?

      user_query = playlist_params[:user_query].to_s.strip
      return if user_query.blank?

      user = User.find_by("users.email ILIKE ?", user_query)
      playlist_params[:user_id] = user.id if user
    end
  end

  index do
    id_column
    column :user
    column :name
    column :private_override
    column "Items" do |playlist|
      link_to "View items (#{playlist.playlist_items.size})", admin_playlist_items_path(q: { playlist_id_eq: playlist.id })
    end
    column :created_at
    column :updated_at
    actions
  end

  filter :name, as: :string
  filter :user_email, as: :string

  form do |f|
    selected_user = f.object.user
    selected_user_label = selected_user&.email || params.dig(:playlist, :user_query).to_s
    f.object.user_query = selected_user_label

    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs do
      f.input :user_query,
              label: "User",
              input_html: {
                id: "playlist-user-query",
                placeholder: "Type to search users",
                autocomplete: "off",
                data: {
                  autocomplete_url: user_options_admin_playlists_path,
                  hidden_id_target: "playlist-user-id",
                  autocomplete_menu_class: "admin-filter-autocomplete-menu",
                  autocomplete_item_class: "admin-filter-autocomplete-item"
                }
              }
      f.input :user_id, as: :hidden, input_html: { id: "playlist-user-id" }

      f.input :name
      f.input :private_override
    end
    f.actions
  end

  sidebar "Playlist Links", only: %i[show edit] do
    ul do
      li link_to("Playlist items", admin_playlist_items_path(q: { playlist_id_eq: resource.id }))
    end
  end
end
