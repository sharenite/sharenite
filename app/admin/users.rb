# frozen_string_literal: true

ActiveAdmin.register User do
  config.sort_order = "created_at_desc"
  config.filters = false
  menu priority: 2
  permit_params :email, :password, :password_confirmation

  controller do
    before_action :normalize_user_password_params, only: %i[create update]

    def destroy
      scheduled_now = Users::ScheduleDeletion.call(resource, scheduled_by_admin_user: current_admin_user)
      message = scheduled_now ? "User deletion has been scheduled." : "User deletion is already in progress."
      redirect_to(safe_return_to_or_collection, notice: message)
    end

    private

    def safe_return_to_or_collection
      return_to = params[:return_to].to_s
      return collection_path if return_to.blank?

      uri = URI.parse(return_to)
      return collection_path unless uri.path == collection_path

      return_to
    rescue URI::InvalidURIError
      collection_path
    end

    def normalize_user_password_params
      return unless params[:user].is_a?(ActionController::Parameters) || params[:user].is_a?(Hash)
      return unless params[:user][:password].blank?

      params[:user].delete(:password)
      params[:user].delete("password")
      params[:user].delete(:password_confirmation)
      params[:user].delete("password_confirmation")
    end
  end

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
    column :deletion_requested_at
    column :games_count do |user|
      games_total = user[:games_count]
      games_total = user.games.count if games_total.nil?
      link_to games_total, admin_user_games_path(user)
    end
    column :current_sign_in_at
    column :current_sign_in_ip
    column :last_sign_in_at
    column :last_sign_in_ip
    column :created_at
    column :updated_at
    actions defaults: false do |user|
      item "View", resource_path(user), class: "member_link view_link"
      item "Edit", edit_resource_path(user), class: "member_link edit_link" unless user.deleting?

      if user.deleting?
        span "Deleting..", class: "member_link"
      else
        item "Delete",
             resource_path(user, return_to: request.fullpath),
             class: "member_link delete_link",
             method: :delete,
             data: { confirm: "Are you sure you want to schedule deletion for this user?" }
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs do
      f.input :email
      f.input :password, required: f.object.new_record?, input_html: { autocomplete: "new-password" }
      f.input :password_confirmation, required: f.object.new_record?, input_html: { autocomplete: "new-password" }
    end
    f.actions
  end

  sidebar "Filters", only: :index do
    q = params.fetch(:q, {})

    form action: collection_path, method: :get, class: "admin-custom-filter-form" do
      div class: "filter_form_field" do
        label "Email"
        input type: "text",
              name: "q[email_cont]",
              value: q[:email_cont].to_s,
              placeholder: "Type to search users",
              autocomplete: "off"
      end

      div class: "filter_form_field filter_range_pair" do
        label "Games count"
        div class: "range_inputs" do
          input type: "number", min: "0", name: "q[games_count_gteq]", value: q[:games_count_gteq].to_s, placeholder: "From"
          input type: "number", min: "0", name: "q[games_count_lteq]", value: q[:games_count_lteq].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Created at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[created_at_gteq]", value: q[:created_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[created_at_lteq_end_of_day]", value: q[:created_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Current sign in at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[current_sign_in_at_gteq]", value: q[:current_sign_in_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[current_sign_in_at_lteq_end_of_day]", value: q[:current_sign_in_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Last sign in at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[last_sign_in_at_gteq]", value: q[:last_sign_in_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[last_sign_in_at_lteq_end_of_day]", value: q[:last_sign_in_at_lteq_end_of_day].to_s, placeholder: "To"
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

  sidebar "User Details", only: %i[show edit] do
    filterable_resources = ActiveAdmin.application.namespaces[:admin]
                                       .resources
                                       .select do |admin_resource|
      next false unless admin_resource.respond_to?(:resource_class)

      model = admin_resource.resource_class
      model < ApplicationRecord &&
        model != User &&
        model.columns_hash.key?("user_id")
    end
                                       .sort_by { |admin_resource| admin_resource.resource_label }

    ul do
      filterable_resources.each do |admin_resource|
        route_helper = "admin_#{admin_resource.resource_name.route_key}_path"
        next unless helpers.respond_to?(route_helper)

        path = helpers.public_send(route_helper, q: { user_id_eq: resource.id })

        li link_to(
          admin_resource.resource_label.pluralize,
          path
        )
      end
      nil
    end
  end

  action_item :destroy, only: :show do
    if resource.deleting?
      span "Deleting..", class: "action_item"
    else
      link_to "Delete User",
              resource_path(resource, return_to: collection_path),
              method: :delete,
              data: { confirm: "Are you sure you want to schedule deletion for this user?" }
    end
  end
end
