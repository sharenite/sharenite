# frozen_string_literal: true

ActiveAdmin.register SyncJob do
  config.sort_order = "created_at_desc"

  menu priority: 4

  belongs_to :user, optional: true
  includes :user

  scope :all, default: true
  scope :status_queued
  scope :status_running
  scope :status_failed
  scope :status_finished
  scope :status_dead

  member_action :mark_dead, method: :put do
    finished_processing_at = Time.current
    resource.update(finished_processing_at:, processing_time: finished_processing_at - resource.started_processing_at)
    resource.status_dead!
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to admin_sync_jobs_path(nil), notice: "SyncJob was marked as dead"
    # rubocop:enable Rails/I18nLocaleTexts
  end

  action_item :mark_dead, only: :show do
    link_to "Mark Dead", mark_dead_admin_sync_job_path(resource), method: :put unless sync_job.status_dead? || sync_job.status_finished?
  end

  batch_action :mark_dead do |ids|
    batch_action_collection
      .find(ids)
      .each do |sync_job|
        finished_processing_at = Time.current
        sync_job.update(finished_processing_at:, processing_time: finished_processing_at - sync_job.started_processing_at)
        sync_job.status_dead!
      end
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to collection_path, alert: "SyncJobs were marked as dead."
    # rubocop:enable Rails/I18nLocaleTexts
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
    actions defaults: true do |sync_job|
      link_to "Dead", mark_dead_admin_sync_job_path(sync_job), method: :put unless sync_job.status_dead? || sync_job.status_finished?
    end
  end

  filter :user_email, as: :string
  filter :status, as: :select, collection: SyncJob.statuses
end
