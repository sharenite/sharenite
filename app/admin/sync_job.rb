# frozen_string_literal: true

ActiveAdmin.register SyncJob do
  config.sort_order = "created_at_desc"
  config.filters = false
  menu priority: 5

  actions :all, except: %i[new create edit update]

  belongs_to :user, optional: true
  includes :user
  actions :index, :show, :destroy

  scope :all, default: true
  scope :status_queued
  scope :status_running
  scope :status_failed
  scope :status_finished
  scope :status_dead
  scope(
    proc { sync_request_gap_scope_label },
    :request_gap_good,
    show_count: false,
    if: proc { sync_request_gap_tone == :good }
  ) { |jobs| jobs }
  scope(
    proc { sync_request_gap_scope_label },
    :request_gap_warn,
    show_count: false,
    if: proc { sync_request_gap_tone == :warn }
  ) { |jobs| jobs }
  scope(
    proc { sync_request_gap_scope_label },
    :request_gap_bad,
    show_count: false,
    if: proc { sync_request_gap_tone == :bad }
  ) { |jobs| jobs }
  scope(
    proc { sync_request_gap_scope_label },
    :request_gap_neutral,
    show_count: false,
    if: proc { sync_request_gap_tone == :neutral }
  ) { |jobs| jobs }

  collection_action :user_options, method: :get do
    query = params[:q].to_s.strip
    users = User.order(:email)
    if query.present?
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
      users = users.where("users.email ILIKE ?", "%#{sanitized_query}%")
    else
      users = users.none
    end
    users = users.limit(20)

    render json: users.map { |user| { id: user.id, label: user.email } }
  end

  controller do
    helper_method :selected_sync_job_user
    helper_method :sync_job_name_options
    helper_method :sync_request_gap_tone
    helper_method :sync_request_gap_scope_label
    before_action :normalize_sync_job_filters, only: :index

    def selected_sync_job_user
      user_id = params.dig(:q, :user_id_eq).presence
      return if user_id.blank?

      @selected_sync_job_user ||= User.find_by(id: user_id)
    end

    def sync_job_name_options
      canonical_names = %w[FullLibrarySyncJob PartialLibrarySyncJob DeleteGamesSyncJob GameSyncJob]

      discovered_names = SyncJob.where.not(name: [nil, ""])
                               .distinct
                               .order(:name)
                               .limit(400)
                               .pluck(:name)
                               .map { |name| name.sub(%r{\s*\(chunk \d+/\d+\)\z}, "").strip }
                               .compact_blank

      (canonical_names + discovered_names).uniq.sort
    end

    def sync_request_gap_scope_label
      stats = sync_request_gap_stats
      return "Req gap: N/A" if stats[:current_gap].nil?

      current_gap_text = humanize_gap(stats[:current_gap])
      avg_gap_text = stats[:avg_gap].present? ? humanize_gap(stats[:avg_gap]) : "N/A"
      "Req gap: #{current_gap_text} / #{avg_gap_text} avg (n=120)"
    end

    def sync_request_gap_tone
      stats = sync_request_gap_stats
      current_gap = stats[:current_gap]
      avg_gap = stats[:avg_gap]
      return :neutral if current_gap.nil? || avg_gap.nil? || avg_gap <= 0

      ratio = current_gap / avg_gap.to_f
      return :good if ratio <= 1.5
      return :warn if ratio <= 3.0

      :bad
    end

    private

    # rubocop:disable Metrics/AbcSize
    def normalize_sync_job_filters
      q = sync_job_query_params
      clear_scope_param! if params[:scope].to_s.start_with?("request_gap_")

      q.delete(:status_eq)
      q.delete("status_eq")
      q[:name_start] = "" if q[:name_start].to_s == "Any" || q["name_start"].to_s == "Any"

      user_id = q[:user_id_eq].presence
      user_query = params[:user_query].to_s.strip

      if user_id.blank? && user_query.present?
        q[:user_email_cont] = user_query
      else
        clear_user_email_filter!(q)
      end
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def sync_request_gap_stats
      @sync_request_gap_stats ||= begin
        rows = SyncJob.order(created_at: :desc)
                      .limit(500)
                      .pluck(:created_at, :id, :sync_batch_id, :payload_chunks, :name, :user_id)

        request_times = []
        seen_keys = {}

        rows.each do |row|
          key = sync_request_key_for_row(row)
          next if seen_keys[key]

          seen_keys[key] = true
          request_times << row[0]
          break if request_times.length >= 120
        end

        latest_request_at = request_times.first
        avg_gap = if request_times.length >= 2
                    gaps = request_times.each_cons(2).map { |current_time, previous_time| current_time - previous_time }
                    gaps.sum / gaps.length
                  end

        {
          current_gap: latest_request_at.present? ? (Time.current - latest_request_at) : nil,
          avg_gap:
        }
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

    def sync_request_key_for_row(row)
      created_at, id, sync_batch_id, payload_chunks, name, user_id = row
      return sync_batch_id.to_s if sync_batch_id.present?

      payload_chunks_count = payload_chunks.to_i
      return id.to_s if payload_chunks_count <= 1

      canonical_name = name.to_s.sub(%r{\s*\(chunk \d+/\d+\)\z}, "")
      "#{user_id}|#{canonical_name}|#{created_at.change(usec: 0)}|#{payload_chunks_count}"
    end

    def sync_job_query_params
      params[:q] = ActionController::Parameters.new unless params[:q].is_a?(ActionController::Parameters) || params[:q].is_a?(Hash)
      params[:q]
    end

    def clear_scope_param!
      params.delete(:scope)
      params.delete("scope")
    end

    def clear_user_email_filter!(query)
      query.delete(:user_email_cont)
      query.delete("user_email_cont")
    end

    def humanize_gap(seconds)
      total_seconds = seconds.to_i
      return "#{total_seconds}s" if total_seconds < 60

      minutes = total_seconds / 60
      remaining_seconds = total_seconds % 60
      return "#{minutes}m #{remaining_seconds}s" if minutes < 60

      hours = minutes / 60
      remaining_minutes = minutes % 60
      return "#{hours}h #{remaining_minutes}m" if hours < 24

      days = hours / 24
      remaining_hours = hours % 24
      "#{days}d #{remaining_hours}h"
    end
  end

  member_action :mark_dead, method: :put do
    unless mark_dead_state!(resource)
      # rubocop:disable Rails/I18nLocaleTexts
      redirect_back fallback_location: collection_path(scope: params[:scope]), alert: "Could not mark SyncJob as dead."
      # rubocop:enable Rails/I18nLocaleTexts
      next
    end

    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back fallback_location: collection_path(scope: params[:scope]), notice: "SyncJob was marked as dead."
    # rubocop:enable Rails/I18nLocaleTexts
  end

  member_action :retry_from_dead, method: :put do
    unless resource.status_dead?
      # rubocop:disable Rails/I18nLocaleTexts
      redirect_to resource_path(resource), alert: "Only dead SyncJobs can be retried."
      # rubocop:enable Rails/I18nLocaleTexts
      next
    end

    retry_payload = dead_retry_payload_for(resource)
    if retry_payload.blank?
      # rubocop:disable Rails/I18nLocaleTexts
      redirect_to resource_path(resource), alert: "Retry payload not available for this dead SyncJob."
      # rubocop:enable Rails/I18nLocaleTexts
      next
    end

    # rubocop:disable Rails/I18nLocaleTexts
    unless redis_exists?("syncjob:#{resource.id}")
      redirect_to resource_path(resource), alert: "Sync payload is missing in Redis. Cannot retry."
      next
    end
    # rubocop:enable Rails/I18nLocaleTexts

    Karafka.producer.produce_sync(
      topic: "library.sync",
      payload: retry_payload.to_json,
      key: resource.user_id,
      partition_key: resource.user_id
    )

    resource.update!(
      status: :queued,
      error_message: nil,
      started_processing_at: nil,
      finished_processing_at: nil,
      waiting_time: nil,
      processing_time: nil
    )

    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to resource_path(resource), notice: "SyncJob was re-queued to library.sync."
    # rubocop:enable Rails/I18nLocaleTexts
  rescue StandardError => e
    redirect_back fallback_location: collection_path(scope: params[:scope]), alert: "Retry failed: #{e.message}"
  end

  action_item :mark_dead, only: :show do
    next if resource.status_dead? || resource.status_finished?

    link_to "Mark Dead", mark_dead_admin_sync_job_path(resource), method: :put
  end

  action_item :retry_from_dead, only: :show do
    next unless resource.status_dead?

    link_to "Retry", retry_from_dead_admin_sync_job_path(resource), method: :put
  end

  batch_action :mark_dead do |ids|
    marked = 0
    skipped = 0
    failed = 0

    selected_sync_jobs(ids).each do |sync_job|
      if sync_job.status_dead? || sync_job.status_finished?
        skipped += 1
        next
      end

      if mark_dead_state!(sync_job)
        marked += 1
      else
        failed += 1
      end
    end

    redirect_back fallback_location: collection_path(scope: params[:scope]), notice: "Marked #{marked} SyncJob(s) as dead. Skipped #{skipped}. Failed #{failed}."
  end

  batch_action :retry_from_dead do |ids|
    retried = 0
    skipped = 0
    failed = 0

    selected_sync_jobs(ids).each do |sync_job|
      unless sync_job.status_dead?
        skipped += 1
        next
      end

      retry_payload = dead_retry_payload_for(sync_job)
      unless retry_payload.present? && redis_exists?("syncjob:#{sync_job.id}")
        skipped += 1
        next
      end

      Karafka.producer.produce_sync(
        topic: "library.sync",
        payload: retry_payload.to_json,
        key: sync_job.user_id,
        partition_key: sync_job.user_id
      )

      sync_job.update!(
        status: :queued,
        error_message: nil,
        started_processing_at: nil,
        finished_processing_at: nil,
        waiting_time: nil,
        processing_time: nil
      )
      retried += 1
    rescue StandardError
      failed += 1
    end

    redirect_back fallback_location: collection_path(scope: params[:scope]), notice: "Retried #{retried} dead SyncJob(s). Skipped #{skipped}. Failed #{failed}."
  end

  batch_action :destroy do |ids|
    deleted = 0
    skipped = 0
    failed = 0

    selected_sync_jobs(ids).each do |sync_job|
      unless sync_job.status_dead?
        skipped += 1
        next
      end

      expire_syncjob_redis_keys(sync_job.id)
      publish_dead_tombstone(sync_job.user_id)
      sync_job.destroy!
      deleted += 1
    rescue StandardError
      failed += 1
    end

    redirect_back fallback_location: collection_path(scope: params[:scope]), notice: "Deleted #{deleted} dead SyncJob(s). Skipped #{skipped} non-dead job(s). Failed #{failed}."
  end

  controller do
    def destroy
      return redirect_non_dead_delete unless resource.status_dead?

      expire_syncjob_redis_keys(resource.id)
      publish_dead_tombstone(resource.user_id)
      resource.destroy!
      redirect_destroy_success
    end

    private

    def mark_dead_state!(sync_job)
      sync_job.update!(dead_timing_attributes(sync_job))
      sync_job.status_dead!
      apply_dead_payload_ttl(sync_job.id)
      persist_dead_retry_payload(sync_job)
      true
    rescue StandardError
      false
    end

    def dead_timing_attributes(sync_job)
      finished_processing_at = Time.current
      attributes = { finished_processing_at: }
      return dead_attributes_for_never_started(sync_job, finished_processing_at, attributes) if sync_job.started_processing_at.nil?

      attributes.merge(processing_time: finished_processing_at - sync_job.started_processing_at)
    end

    def dead_attributes_for_never_started(sync_job, finished_processing_at, attributes)
      attributes.merge(
        started_processing_at: finished_processing_at,
        waiting_time: finished_processing_at - sync_job.created_at,
        processing_time: 0
      )
    end

    def dead_retry_payload_for(sync_job)
      payload = read_dead_retry_payload(sync_job.id)
      return payload if payload.present?

      inferred_retry_payload(sync_job)
    end

    def read_dead_retry_payload(sync_job_id)
      raw_payload = redis_get(dead_retry_payload_redis_key(sync_job_id))
      return if raw_payload.blank?

      JSON.parse(raw_payload)
    rescue JSON::ParserError
      nil
    end

    def persist_dead_retry_payload(sync_job)
      payload = inferred_retry_payload(sync_job)
      return if payload.blank?

      redis_set(dead_retry_payload_redis_key(sync_job.id), payload.to_json, expires_in: dead_syncjob_payload_ttl)
    end

    def inferred_retry_payload(sync_job)
      type = sync_job_type(sync_job.name)
      return if type.blank?
      return if type == "full" && sync_job.payload_chunks.to_i > 1

      {
        type:,
        current_user_id: sync_job.user_id,
        job_id: sync_job.id,
        total_chunks: sync_job.payload_chunks,
        chunk_index: sync_job.payload_chunk_index
      }.compact
    end

    def sync_job_type(job_name)
      return "full" if job_name.start_with?("FullLibrarySyncJob")
      return "partial" if job_name.start_with?("PartialLibrarySyncJob")
      return "delete" if job_name.start_with?("DeleteGamesSyncJob")
      return "single" if job_name.start_with?("GameSyncJob")

      nil
    end

    def apply_dead_payload_ttl(sync_job_id)
      redis_expire("syncjob:#{sync_job_id}", dead_syncjob_payload_ttl)
    end

    def expire_syncjob_redis_keys(sync_job_id)
      redis_expire("syncjob:#{sync_job_id}", 1)
      redis_expire(dead_retry_payload_redis_key(sync_job_id), 1)
    end

    def dead_retry_payload_redis_key(sync_job_id)
      "syncjob_dead_payload:#{sync_job_id}"
    end

    def redis_get(key)
      # rubocop:disable Style/GlobalVars
      $redis.get(key)
      # rubocop:enable Style/GlobalVars
    end

    def redis_set(key, value, expires_in:)
      # rubocop:disable Style/GlobalVars
      $redis.set(key, value, ex: expires_in)
      # rubocop:enable Style/GlobalVars
    end

    def redis_expire(key, ttl)
      # rubocop:disable Style/GlobalVars
      $redis.expire(key, ttl)
      # rubocop:enable Style/GlobalVars
    end

    def redis_exists?(key)
      # rubocop:disable Style/GlobalVars
      $redis.exists?(key).positive?
      # rubocop:enable Style/GlobalVars
    end

    def dead_syncjob_payload_ttl
      2_678_400
    end

    def selected_sync_jobs(ids)
      # Do not use `.find(ids)` here: in scoped views records can disappear between selection and submit.
      batch_action_collection.where(id: ids)
    end

    def publish_dead_tombstone(user_id)
      Karafka.producer.produce_sync(
        topic: "dead.messages",
        payload: nil,
        key: user_id,
        partition_key: user_id
      )
    rescue StandardError
      nil
    end

    def redirect_non_dead_delete
      # rubocop:disable Rails/I18nLocaleTexts
      redirect_back fallback_location: collection_path(scope: params[:scope]), alert: "Only dead SyncJobs can be deleted."
      # rubocop:enable Rails/I18nLocaleTexts
    end

    def redirect_destroy_success
      # rubocop:disable Rails/I18nLocaleTexts
      redirect_back fallback_location: collection_path(scope: params[:scope]), notice: "SyncJob was deleted."
      # rubocop:enable Rails/I18nLocaleTexts
    end
  end

  index do
    selectable_column
    id_column
    column :user
    column :name
    column :games_count if SyncJob.columns_hash.key?("games_count")
    column :status
    column :created_at
    column :updated_at
    column :payload_size_bytes
    column :payload_chunks
    column :payload_chunk_index
    column :waiting_time do |sync_job|
      Time.at(sync_job.waiting_time).utc.strftime("%H:%M:%S") unless sync_job.waiting_time.nil?
    end
    column :processing_time do |sync_job|
      Time.at(sync_job.processing_time).utc.strftime("%H:%M:%S") unless sync_job.processing_time.nil?
    end
    actions defaults: false do |sync_job|
      links = []
      links << link_to("View", resource_path(sync_job))
      links << link_to("Dead", mark_dead_admin_sync_job_path(sync_job), method: :put) unless sync_job.status_dead? || sync_job.status_finished?
      links << link_to("Retry", retry_from_dead_admin_sync_job_path(sync_job), method: :put) if sync_job.status_dead?
      links << link_to("Delete", resource_path(sync_job), method: :delete) if sync_job.status_dead?
      span safe_join(links, " | ".html_safe)
    end
  end

  show do
    attributes_table do
      row :id
      row :user
      row :name
      row :status
      row :sync_batch_id if SyncJob.columns_hash.key?("sync_batch_id")
      row :games_count if SyncJob.columns_hash.key?("games_count")
      row :payload_size_bytes
      row :payload_chunks
      row :payload_chunk_index
      row :error_message
      row :created_at
      row :updated_at
      row :started_processing_at
      row :finished_processing_at
      row("Waiting time (s)", &:waiting_time)
      row("Processing time (s)", &:processing_time)
    end
  end

  sidebar "Filters", only: :index do
    q = params.fetch(:q, {})
    selected_user = selected_sync_job_user
    selected_user_label = selected_user&.email || params[:user_query].to_s

    form action: collection_path, method: :get, class: "admin-custom-filter-form" do
      input type: "hidden", name: "scope", value: params[:scope] if params[:scope].present?

      div class: "filter_form_field" do
        label "User email"
        input type: "text",
              id: "sync-job-user-query",
              name: "user_query",
              value: selected_user_label,
              placeholder: "Type to search users",
              autocomplete: "off",
              "data-autocomplete-url": user_options_admin_sync_jobs_path,
              "data-hidden-id-target": "sync-job-user-id"
        input type: "hidden", id: "sync-job-user-id", name: "q[user_id_eq]", value: q[:user_id_eq].to_s
      end

      div class: "filter_form_field" do
        label "Name"
        select name: "q[name_start]" do
          option "Any", value: "", selected: q[:name_start].blank?
          sync_job_name_options.each do |name_option|
            option name_option, value: name_option, selected: (q[:name_start].to_s == name_option)
          end
        end
      end

      if SyncJob.columns_hash.key?("sync_batch_id")
        div class: "filter_form_field" do
          label "Sync batch ID"
          input type: "text",
                name: "q[sync_batch_id_eq]",
                value: q[:sync_batch_id_eq].to_s,
                placeholder: "Exact batch UUID"
        end
      end

      if SyncJob.columns_hash.key?("games_count")
        div class: "filter_form_field filter_range_pair" do
          label "Games count"
          div class: "range_inputs" do
            input type: "number", min: "0", name: "q[games_count_gteq]", value: q[:games_count_gteq].to_s, placeholder: "From"
            input type: "number", min: "0", name: "q[games_count_lteq]", value: q[:games_count_lteq].to_s, placeholder: "To"
          end
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Waiting time (s)"
        div class: "range_inputs" do
          input type: "number", min: "0", name: "q[waiting_time_gteq]", value: q[:waiting_time_gteq].to_s, placeholder: "From"
          input type: "number", min: "0", name: "q[waiting_time_lteq]", value: q[:waiting_time_lteq].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Processing time (s)"
        div class: "range_inputs" do
          input type: "number", min: "0", name: "q[processing_time_gteq]", value: q[:processing_time_gteq].to_s, placeholder: "From"
          input type: "number", min: "0", name: "q[processing_time_lteq]", value: q[:processing_time_lteq].to_s, placeholder: "To"
        end
      end

      div class: "filter_form_field filter_range_pair" do
        label "Created"
        div class: "range_inputs" do
          input type: "text", class: "datepicker", name: "q[created_at_gteq]", value: q[:created_at_gteq].to_s, placeholder: "From"
          input type: "text", class: "datepicker", name: "q[created_at_lteq_end_of_day]", value: q[:created_at_lteq_end_of_day].to_s, placeholder: "To"
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
end
