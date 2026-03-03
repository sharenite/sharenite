# frozen_string_literal: true

ActiveAdmin.register Profile do
  config.sort_order = "created_at_desc"
  menu parent: "Users", priority: 1

  belongs_to :user, optional: true
  includes :user
  permit_params :user_id, :name, :vanity_url, :privacy, :game_library_privacy

  controller do
    before_action :normalize_profile_user_param, only: %i[create update]

    # Profiles use FriendlyId (slug in URLs), but ActiveAdmin defaults to PK lookup.
    def find_resource
      scoped_collection.friendly.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      scoped_collection.find(params[:id])
    end

    private

    def normalize_profile_user_param
      return unless params[:profile].is_a?(ActionController::Parameters) || params[:profile].is_a?(Hash)

      user_id = params.dig(:profile, :user_id).presence || params.dig(:profile, "user_id").presence
      return if user_id.present?

      user_query = params.dig(:profile, :user_query).to_s.strip
      return if user_query.blank?

      user = User.find_by("users.email ILIKE ?", user_query)
      return unless user

      params[:profile][:user_id] = user.id
      params[:profile]["user_id"] = user.id
    end
  end

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

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  # permit_params :name, :user_id
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :user_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  index do
    id_column
    column :user
    column :name
    column :vanity_url
    column :privacy
    column :game_library_privacy
    column :created_at
    column :updated_at
    actions
  end

  filter :name
  filter :vanity_url
  filter :privacy, as: :select, collection: Profile.privacies.keys
  filter :game_library_privacy, as: :select, collection: Profile.game_library_privacies.keys
  filter :user_email, as: :string
  filter :created_at
  filter :updated_at

  form do |f|
    selected_user = f.object.user
    selected_user_label = selected_user&.email || params.dig(:profile, :user_query).to_s
    f.object.user_query = selected_user_label

    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs do
      f.input :user_query,
              label: "User",
              input_html: {
                id: "profile-user-query",
                placeholder: "Type to search users",
                autocomplete: "off",
                data: {
                  autocomplete_url: user_options_admin_profiles_path,
                  hidden_id_target: "profile-user-id",
                  autocomplete_menu_class: "admin-filter-autocomplete-menu",
                  autocomplete_item_class: "admin-filter-autocomplete-item"
                }
              }
      f.input :user_id, as: :hidden, input_html: { id: "profile-user-id" }

      f.input :name
      f.input :vanity_url
      f.input :privacy, as: :select, collection: Profile.privacies.keys
      f.input :game_library_privacy, as: :select, collection: Profile.game_library_privacies.keys
    end
    f.actions
  end
end
