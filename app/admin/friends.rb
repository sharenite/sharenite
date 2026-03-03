# frozen_string_literal: true

ActiveAdmin.register Friend do
  config.sort_order = "created_at_desc"
  config.filters = false
  menu priority: 3
  includes :inviter, :invitee
  permit_params :inviter_id, :invitee_id, :status

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
    before_action :normalize_friend_filters, only: :index
    before_action :normalize_friend_form_params, only: %i[create update]

    private

    def normalize_friend_filters
      return unless params[:q].is_a?(ActionController::Parameters) || params[:q].is_a?(Hash)

      status = params.dig(:q, :status_eq).presence || params.dig(:q, "status_eq").presence
      unless status.blank? || Friend.statuses.key?(status)
        params[:q][:status_eq] = ""
        params[:q]["status_eq"] = ""
      end

      normalize_friend_user_filter(:inviter)
      normalize_friend_user_filter(:invitee)
    end

    def normalize_friend_user_filter(kind)
      id_key = :"#{kind}_id_eq"
      email_key = :"#{kind}_email_cont"
      query_key = :"#{kind}_query"

      selected_id = params.dig(:q, id_key).presence || params.dig(:q, id_key.to_s).presence
      query = params[query_key].to_s.strip

      if selected_id.present?
        params[:q].delete(email_key)
        params[:q].delete(email_key.to_s)
      elsif query.present?
        params[:q][email_key] = query
      else
        params[:q].delete(email_key)
        params[:q].delete(email_key.to_s)
      end
    end

    def normalize_friend_form_params
      return unless params[:friend].is_a?(ActionController::Parameters) || params[:friend].is_a?(Hash)

      normalize_friend_user_param(:inviter)
      normalize_friend_user_param(:invitee)
    end

    def normalize_friend_user_param(kind)
      id_key = :"#{kind}_id"
      query_key = :"#{kind}_query"
      user_id = params.dig(:friend, id_key).presence || params.dig(:friend, id_key.to_s).presence
      return if user_id.present?

      user_query = params.dig(:friend, query_key).to_s.strip
      return if user_query.blank?

      user = User.find_by("users.email ILIKE ?", user_query)
      return unless user

      params[:friend][id_key] = user.id
      params[:friend][id_key.to_s] = user.id
    end
  end

  index do
    id_column
    column("Inviter") { |friend| friend.inviter&.email }
    column("Invitee") { |friend| friend.invitee&.email }
    column :status
    column :created_at
    column :updated_at
    actions
  end

  sidebar "Filters", only: :index do
    q = params.fetch(:q, {})
    selected_inviter = User.find_by(id: q[:inviter_id_eq].presence)
    selected_invitee = User.find_by(id: q[:invitee_id_eq].presence)

    form action: collection_path, method: :get, class: "admin-custom-filter-form" do
      div class: "filter_form_field" do
        label "Inviter email"
        input type: "text",
              id: "friend-filter-inviter-query",
              name: "inviter_query",
              value: (selected_inviter&.email || params[:inviter_query].to_s),
              placeholder: "Type to search users",
              autocomplete: "off",
              "data-autocomplete-url": user_options_admin_friends_path,
              "data-hidden-id-target": "friend-filter-inviter-id",
              "data-autocomplete-menu-class": "admin-filter-autocomplete-menu",
              "data-autocomplete-item-class": "admin-filter-autocomplete-item"
        input type: "hidden", id: "friend-filter-inviter-id", name: "q[inviter_id_eq]", value: q[:inviter_id_eq].to_s
      end

      div class: "filter_form_field" do
        label "Invitee email"
        input type: "text",
              id: "friend-filter-invitee-query",
              name: "invitee_query",
              value: (selected_invitee&.email || params[:invitee_query].to_s),
              placeholder: "Type to search users",
              autocomplete: "off",
              "data-autocomplete-url": user_options_admin_friends_path,
              "data-hidden-id-target": "friend-filter-invitee-id",
              "data-autocomplete-menu-class": "admin-filter-autocomplete-menu",
              "data-autocomplete-item-class": "admin-filter-autocomplete-item"
        input type: "hidden", id: "friend-filter-invitee-id", name: "q[invitee_id_eq]", value: q[:invitee_id_eq].to_s
      end

      div class: "filter_form_field" do
        label "Status"
        select name: "q[status_eq]" do
          text_node(%(<option value=""#{' selected="selected"' if q[:status_eq].blank?}>Any</option>).html_safe)
          Friend.statuses.keys.each do |status|
            option status, value: status, selected: q[:status_eq].to_s == status
          end
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Created"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[created_at_gteq]", value: q[:created_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[created_at_lteq_end_of_day]", value: q[:created_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Updated"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[updated_at_gteq]", value: q[:updated_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[updated_at_lteq_end_of_day]", value: q[:updated_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "buttons" do
        button "Apply", type: "submit"
        span do
          text_node " "
          a "Clear", href: collection_path
        end
      end
    end
  end

  form do |f|
    selected_inviter = f.object.inviter
    selected_invitee = f.object.invitee
    f.object.inviter_query = selected_inviter&.email || params.dig(:friend, :inviter_query).to_s
    f.object.invitee_query = selected_invitee&.email || params.dig(:friend, :invitee_query).to_s

    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs do
      f.input :inviter_query,
              label: "Inviter email",
              input_html: {
                id: "friend-inviter-query",
                placeholder: "Type to search users",
                autocomplete: "off",
                data: {
                  autocomplete_url: user_options_admin_friends_path,
                  hidden_id_target: "friend-inviter-id",
                  autocomplete_menu_class: "admin-filter-autocomplete-menu",
                  autocomplete_item_class: "admin-filter-autocomplete-item"
                }
              }
      f.input :inviter_id, as: :hidden, input_html: { id: "friend-inviter-id" }

      f.input :invitee_query,
              label: "Invitee email",
              input_html: {
                id: "friend-invitee-query",
                placeholder: "Type to search users",
                autocomplete: "off",
                data: {
                  autocomplete_url: user_options_admin_friends_path,
                  hidden_id_target: "friend-invitee-id",
                  autocomplete_menu_class: "admin-filter-autocomplete-menu",
                  autocomplete_item_class: "admin-filter-autocomplete-item"
                }
              }
      f.input :invitee_id, as: :hidden, input_html: { id: "friend-invitee-id" }

      f.input :status, as: :select, collection: Friend.statuses.keys
    end
    f.actions
  end
end
  
