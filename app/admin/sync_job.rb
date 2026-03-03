# frozen_string_literal: true

ActiveAdmin.register SyncJob do
  config.sort_order = "created_at_desc"
  menu priority: 5

  belongs_to :user, optional: true
  includes :user
  actions :index, :show, :destroy

  scope :all, default: true
  scope :status_queued
  scope :status_running
  scope :status_failed
  scope :status_finished
  scope :status_dead

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
    column :status
    column :created_at
    column :updated_at
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

  filter :user_email, as: :string
  filter :status, as: :select, collection: SyncJob.statuses
end
