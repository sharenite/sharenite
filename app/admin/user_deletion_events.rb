# frozen_string_literal: true

ActiveAdmin.register UserDeletionEvent do
  menu parent: "Users", label: "Deletion Events", priority: 2
  actions :index, :show
  config.sort_order = "requested_at_desc"

  filter :status, as: :select, collection: proc { UserDeletionEvent.statuses.keys.map { |value| [value.humanize, value] } }
  filter :scheduled_by_admin
  filter :scheduled_by_admin_email
  filter :requested_at
  filter :job_started_at
  filter :job_succeeded_at
  filter :job_failed_at
  filter :created_at

  index do
    id_column
    column :status
    column :scheduled_by_admin
    column("Admin Email") do |event|
      email = event.scheduled_by_admin_email
      next "N/A" if email.blank?
      if event.scheduled_by_admin_user.present?
        link_to(email, admin_admin_users_path(q: { email_eq: email }))
      else
        email
      end
    end
    column :requested_at
    column :job_started_at
    column :job_succeeded_at
    column :job_failed_at
    column("Request -> Success (s)") { |event| event.request_to_success_seconds || "N/A" }
    column("Job Duration (s)") { |event| event.job_duration_seconds || "N/A" }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :status
      row :scheduled_by_admin
      row("Admin Email") do
        email = resource.scheduled_by_admin_email
        next "N/A" if email.blank?
        if resource.scheduled_by_admin_user.present?
          link_to(email, admin_admin_users_path(q: { email_eq: email }))
        else
          email
        end
      end
      row :requested_at
      row :job_started_at
      row :job_succeeded_at
      row :job_failed_at
      row("Request -> Success (s)") { resource.request_to_success_seconds || "N/A" }
      row("Job Duration (s)") { resource.job_duration_seconds || "N/A" }
      row :created_at
      row :updated_at
    end
  end
end
