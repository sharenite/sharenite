# frozen_string_literal: true

ActiveAdmin.register RequestThrottleEvent do
  menu priority: 6, label: "Request Limits"
  actions :index, :show
  config.sort_order = "last_seen_at_desc"
  config.filters = false

  scope(proc { request_throttle_scope_label(:all) }, :all, default: true, show_count: false)
  scope(proc { request_throttle_scope_label(:current) }, :current, show_count: false)
  scope(proc { request_throttle_scope_label(:historical) }, :historical, show_count: false)
  scope(proc { request_throttle_scope_label(:throttle_events) }, :throttle_events, show_count: false)
  scope(proc { request_throttle_scope_label(:block_events) }, :block_events, show_count: false)
  scope(proc { request_throttle_scope_label(:permanent_blocks) }, :permanent_blocks, show_count: false)

  controller do
    helper_method :request_throttle_scope_label
    before_action :normalize_request_throttle_filters, only: :index

    def request_throttle_scope_label(scope_name)
      count = request_throttle_scope_counts.fetch(scope_name.to_sym, 0)
      "#{scope_name.to_s.humanize} (#{count})"
    end

    private

        def request_throttle_scope_counts
      return cached_request_throttle_scope_counts if request_throttle_scope_counts_globally_cacheable?

      row = request_throttle_scope_counts_relation.pick(*request_throttle_scope_count_expressions)

      build_request_throttle_scope_counts(row)
    end
        def cached_request_throttle_scope_counts
      cache_key = "admin/request_throttle_events/scope_counts/#{Time.current.to_i / 30}"

      Rails.cache.fetch(cache_key, expires_in: 35.seconds) do
        row = RequestThrottleEvent.pick(*request_throttle_scope_count_expressions)
        build_request_throttle_scope_counts(row)
      end
    end

    def build_request_throttle_scope_counts(row)
      {
        all: row&.[](0).to_i,
        current: row&.[](1).to_i,
        historical: row&.[](2).to_i,
        throttle_events: row&.[](3).to_i,
        block_events: row&.[](4).to_i,
        permanent_blocks: row&.[](5).to_i
      }
    end

    def request_throttle_scope_counts_globally_cacheable?
      request_throttle_active_scope.blank? && request_throttle_scope_counts_query.blank?
    end

    def request_throttle_scope_counts_relation
      relation = apply_authorization_scope(scoped_collection)
      relation = apply_scoping(relation)
      query = request_throttle_scope_counts_query

      relation = relation.ransack(query).result if query.present?
      relation.unscope(:select, :order)
    end

    def request_throttle_scope_counts_query
      request_throttle_query_params.to_unsafe_h.compact_blank
    end

    def request_throttle_active_scope
      scope = params[:scope].to_s
      scope unless scope.blank? || scope == "all"
    end

    def request_throttle_query_params
      params[:q] = ActionController::Parameters.new unless params[:q].is_a?(ActionController::Parameters) || params[:q].is_a?(Hash)
      params[:q]
    end

    def normalize_request_throttle_filters
      q = request_throttle_query_params

      %i[event_type_eq actor_type_eq request_method_eq permanent_eq].each do |key|
        q[key] = "" if q[key].to_s == "Any" || q[key.to_s].to_s == "Any"
      end
    end

    def request_throttle_scope_count_expressions
      now = ActiveRecord::Base.connection.quote(Time.current)

      [
        "COUNT(*)",
        "COALESCE(SUM(CASE WHEN lifted_at IS NULL AND (permanent = TRUE OR expires_at > #{now}) THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN lifted_at IS NOT NULL OR (permanent = FALSE AND expires_at <= #{now}) THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN event_type = 'throttle' THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN event_type = 'block' THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN event_type = 'block' AND permanent = TRUE THEN 1 ELSE 0 END), 0)"
      ].map { |expression| Arel.sql(expression) }
    end
  end

  index do
    id_column
    column("Status") do |event|
      span event.status_label, class: "admin-health-value #{event.current? ? 'is-bad' : 'is-neutral'}"
    end
    column("Event Type") do |event|
      span event.event_type, class: "admin-health-value #{event.event_type == 'block' ? 'is-bad' : 'is-warning'}"
    end
    column :rule_name
    column("Subject") do |event|
      if event.user.present?
        link_to(event.subject_label, admin_user_path(event.user))
      else
        event.subject_label
      end
    end
    column :ip_address
    column(:request) { |event| "#{event.request_method} #{event.request_path}" }
    column(:window) { |event| "#{event.limit_value}/#{event.period_seconds}s" }
    column :hit_count
    column :peak_count
    column :escalation_value
    column :started_at
    column :last_seen_at
    column :expires_at
    column :lifted_at
    column :permanent
    actions defaults: true do |event|
      next unless event.permanent? && event.current?

      item "Lift", lift_admin_request_throttle_event_path(event), method: :put
    end
  end

  show do
    attributes_table do
      row :id
      row("Status") do |event|
        span event.status_label, class: "admin-health-value #{event.current? ? 'is-bad' : 'is-neutral'}"
      end
      row("Event Type") do |event|
        span event.event_type, class: "admin-health-value #{event.event_type == 'block' ? 'is-bad' : 'is-warning'}"
      end
      row :rule_name
      row :actor_type
      row :actor_key
      row :user do |event|
        next "N/A" if event.user.blank?

        link_to(event.user.email, admin_user_path(event.user))
      end
      row :ip_address
      row :request_method
      row :request_path
      row :limit_value
      row :period_seconds
      row :hit_count
      row :peak_count
      row :escalation_value
      row :started_at
      row :last_seen_at
      row :expires_at
      row :lifted_at
      row :permanent
      row :created_at
      row :updated_at
    end
  end

  member_action :lift, method: :put do
    # rubocop:disable Rails/I18nLocaleTexts
    if RequestThrottling.lift_permanent_block!(resource)
      redirect_to resource_path(resource), notice: "Permanent block lifted."
    else
      redirect_to resource_path(resource), alert: "Could not lift block."
    end
    # rubocop:enable Rails/I18nLocaleTexts
  end

  collection_action :manual_block, method: :post do
    ip_address = params[:ip_address].to_s.strip

    # rubocop:disable Rails/I18nLocaleTexts
    if RequestThrottling.manually_block_ip!(ip_address)
      redirect_to collection_path(scope: params[:scope].presence), notice: "IP block added for #{ip_address}."
    else
      redirect_to collection_path(scope: params[:scope].presence), alert: "Could not block that IP."
    end
    # rubocop:enable Rails/I18nLocaleTexts
  end

  action_item :lift, only: :show do
    next unless resource.permanent? && resource.current?

    link_to "Lift Block", lift_admin_request_throttle_event_path(resource), method: :put
  end

  sidebar "Filters", only: :index do
    q = params.fetch(:q, {})
    request_method_options = %w[GET POST PUT PATCH DELETE]

    form action: collection_path, method: :get, class: "admin-custom-filter-form" do
      input type: "hidden", name: "scope", value: params[:scope] if params[:scope].present?

      div class: "filter_form_field" do
        label "Event type"
        select name: "q[event_type_eq]" do
          option "Any", value: "", selected: q[:event_type_eq].blank?
          RequestThrottleEvent::EVENT_TYPES.each do |event_type|
            option event_type.humanize, value: event_type, selected: q[:event_type_eq].to_s == event_type
          end
        end
      end

      div class: "filter_form_field" do
        label "Rule name"
        input type: "text", name: "q[rule_name_cont]", value: q[:rule_name_cont].to_s
      end

      div class: "filter_form_field" do
        label "Actor type"
        select name: "q[actor_type_eq]" do
          option "Any", value: "", selected: q[:actor_type_eq].blank?
          RequestThrottleEvent::ACTOR_TYPES.each do |actor_type|
            option actor_type.humanize, value: actor_type, selected: q[:actor_type_eq].to_s == actor_type
          end
        end
      end

      div class: "filter_form_field" do
        label "Actor key"
        input type: "text", name: "q[actor_key_cont]", value: q[:actor_key_cont].to_s
      end

      div class: "filter_form_field" do
        label "User ID"
        input type: "text", name: "q[user_id_eq]", value: q[:user_id_eq].to_s
      end

      div class: "filter_form_field" do
        label "IP address"
        input type: "text", name: "q[ip_address_cont]", value: q[:ip_address_cont].to_s
      end

      div class: "filter_form_field" do
        label "Request method"
        select name: "q[request_method_eq]" do
          option "Any", value: "", selected: q[:request_method_eq].blank?
          request_method_options.each do |request_method|
            option request_method, value: request_method, selected: q[:request_method_eq].to_s == request_method
          end
        end
      end

      div class: "filter_form_field" do
        label "Request path"
        input type: "text", name: "q[request_path_cont]", value: q[:request_path_cont].to_s
      end

      div class: "filter_form_field" do
        label "Permanent"
        select name: "q[permanent_eq]" do
          option "Any", value: "", selected: q[:permanent_eq].blank?
          option "Yes", value: "true", selected: q[:permanent_eq].to_s == "true"
          option "No", value: "false", selected: q[:permanent_eq].to_s == "false"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Started at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[started_at_gteq]", value: q[:started_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[started_at_lteq_end_of_day]", value: q[:started_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Last seen at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[last_seen_at_gteq]", value: q[:last_seen_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[last_seen_at_lteq_end_of_day]", value: q[:last_seen_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Expires at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[expires_at_gteq]", value: q[:expires_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[expires_at_lteq_end_of_day]", value: q[:expires_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Lifted at"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[lifted_at_gteq]", value: q[:lifted_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[lifted_at_lteq_end_of_day]", value: q[:lifted_at_lteq_end_of_day].to_s, placeholder: "To"
        end
      end

      div class: "buttons" do
        button "Apply", type: "submit"
        span do
          text_node " "
          a "Clear", href: collection_path(scope: params[:scope].presence)
        end
      end
    end
  end

  sidebar "Manual Block", only: :index do
    form action: manual_block_admin_request_throttle_events_path, method: :post do
      input type: "hidden", name: helpers.request_forgery_protection_token, value: helpers.form_authenticity_token
      input type: "hidden", name: "scope", value: params[:scope] if params[:scope].present?

      div class: "filter_form_field" do
        label "IP address"
        input type: "text", name: "ip_address", placeholder: "203.0.113.42"
      end

      div class: "buttons" do
        button "Block IP", type: "submit"
      end
    end
  end
end
