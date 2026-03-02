# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    now = Time.current
    window_30_days = 30.days.ago..now
    previous_30_days = 60.days.ago...30.days.ago

    percent_change = lambda do |current_value, previous_value|
      if previous_value.zero?
        current_value.zero? ? "0.0%" : "+100.0%"
      else
        change = ((current_value - previous_value).to_f / previous_value * 100).round(1)
        format("%+.1f%%", change)
      end
    end
    trend_class = lambda do |change_text|
      return "is-neutral" unless change_text.start_with?("+", "-")
      return "is-up" if change_text.start_with?("+")

      "is-down"
    end
    number = ->(value) { helpers.number_with_delimiter(value) }

    users_total = User.count
    users_new_30d = User.where(created_at: window_30_days).count
    users_new_prev_30d = User.where(created_at: previous_30_days).count
    users_confirmed_total = User.where.not(confirmed_at: nil).count
    users_confirmed_30d = User.where(confirmed_at: window_30_days).count
    users_active_sign_in_30d = User.where(last_sign_in_at: window_30_days).count

    sync_jobs_30d = SyncJob.where(created_at: window_30_days)
    sync_jobs_prev_30d = SyncJob.where(created_at: previous_30_days)
    sync_events_30d = sync_jobs_30d.count
    sync_active_users_30d = sync_jobs_30d.select(:user_id).distinct.count
    sync_finished_30d = sync_jobs_30d.where(status: :finished).count
    sync_failed_30d = sync_jobs_30d.where(status: :failed).count
    sync_dead_30d = sync_jobs_30d.where(status: :dead).count
    sync_running_30d = sync_jobs_30d.where(status: :running).count
    sync_events_prev_30d = sync_jobs_prev_30d.count
    sync_avg_processing_time = sync_jobs_30d.where.not(processing_time: nil).average(:processing_time)&.round(2)
    sync_terminal_count = sync_finished_30d + sync_failed_30d + sync_dead_30d
    sync_success_rate = if sync_terminal_count.zero?
                          "N/A"
                        else
                          "#{((sync_finished_30d.to_f / sync_terminal_count) * 100).round(1)}%"
                        end

    users_active_both_30d = User.where(id: sync_jobs_30d.select(:user_id).distinct, last_sign_in_at: window_30_days).count
    users_sync_only_30d = [sync_active_users_30d - users_active_both_30d, 0].max
    users_sign_in_only_30d = [users_active_sign_in_30d - users_active_both_30d, 0].max

    games_total = Game.count
    games_new_30d = Game.where(created_at: window_30_days).count
    games_new_prev_30d = Game.where(created_at: previous_30_days).count
    games_with_recent_activity = Game.where(last_activity: window_30_days).count
    games_installed = Game.where(is_installed: true).count
    games_favorite = Game.where(favorite: true).count
    games_with_notes = Game.where.not(notes: [nil, ""]).count
    avg_games_per_user = users_total.zero? ? 0 : (games_total.to_f / users_total).round(2)

    top_sync_users = User
      .joins(:sync_jobs)
      .where(sync_jobs: { created_at: window_30_days })
      .select("users.*, COUNT(sync_jobs.id) AS sync_jobs_count")
      .group("users.id")
      .order("sync_jobs_count DESC")
      .limit(8)

    top_games_added_users = User
      .joins(:games)
      .where(games: { created_at: window_30_days })
      .select("users.*, COUNT(games.id) AS games_added_count")
      .group("users.id")
      .order("games_added_count DESC")
      .limit(8)

    users_vs_prev_30d = percent_change.call(users_new_30d, users_new_prev_30d)
    games_vs_prev_30d = percent_change.call(games_new_30d, games_new_prev_30d)
    sync_events_vs_prev_30d = percent_change.call(sync_events_30d, sync_events_prev_30d)

    div class: "admin-dashboard" do
      div class: "admin-dashboard-kpis" do
        div class: "admin-kpi-card" do
          div "Total users", class: "admin-kpi-label"
          div number.call(users_total), class: "admin-kpi-value"
          div "Confirmed: #{number.call(users_confirmed_total)}", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "New users (30d)", class: "admin-kpi-label"
          div number.call(users_new_30d), class: "admin-kpi-value"
          span users_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(users_vs_prev_30d)}"
        end
        div class: "admin-kpi-card" do
          div "Active users (30d)", class: "admin-kpi-label"
          div number.call(users_active_sign_in_30d), class: "admin-kpi-value"
          div "Sync-active: #{number.call(sync_active_users_30d)}", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "Total games", class: "admin-kpi-label"
          div number.call(games_total), class: "admin-kpi-value"
          div "Installed: #{number.call(games_installed)}", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "New games (30d)", class: "admin-kpi-label"
          div number.call(games_new_30d), class: "admin-kpi-value"
          span games_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(games_vs_prev_30d)}"
        end
        div class: "admin-kpi-card" do
          div "Sync success rate", class: "admin-kpi-label"
          div sync_success_rate, class: "admin-kpi-value"
          div "Avg processing: #{sync_avg_processing_time || 'N/A'}s", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "Sync events (30d)", class: "admin-kpi-label"
          div number.call(sync_events_30d), class: "admin-kpi-value"
          span sync_events_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(sync_events_vs_prev_30d)}"
        end
      end

      columns do
        column do
          panel "Users Overview" do
            attributes_table_for :users do
              row("Total users") { number.call(users_total) }
              row("Confirmed users") { number.call(users_confirmed_total) }
              row("New users (30d)") { number.call(users_new_30d) }
              row("New users (prev 30d)") { number.call(users_new_prev_30d) }
              row("New users trend (30d vs prev 30d)") { users_vs_prev_30d }
              row("Confirmed users (30d)") { number.call(users_confirmed_30d) }
            end
          end
        end

        column do
          panel "Sync Jobs Health (30 days)" do
            attributes_table_for :sync_jobs do
              row("Finished") { number.call(sync_finished_30d) }
              row("Failed") { number.call(sync_failed_30d) }
              row("Dead") { number.call(sync_dead_30d) }
              row("Running") { number.call(sync_running_30d) }
              row("Success rate (finished/(finished+failed+dead))") { sync_success_rate }
              row("Avg processing time (s)") { sync_avg_processing_time || "N/A" }
            end
          end
        end
      end

      columns do
        column do
          panel "Activity Correlation (30 days)" do
            attributes_table_for :activity do
              row("Users active by sign-in") { number.call(users_active_sign_in_30d) }
              row("Users active by sync job") { number.call(sync_active_users_30d) }
              row("Games with activity") { number.call(games_with_recent_activity) }
              row("Active in both (sign-in + sync)") { number.call(users_active_both_30d) }
              row("Sign-in only") { number.call(users_sign_in_only_30d) }
              row("Sync-only") { number.call(users_sync_only_30d) }
            end
            para "Useful to compare auth activity, sync activity, and actual game engagement."
          end
        end

        column do
          panel "Games Overview" do
            attributes_table_for :games do
              row("Total games") { number.call(games_total) }
              row("New games (30d)") { number.call(games_new_30d) }
              row("New games (prev 30d)") { number.call(games_new_prev_30d) }
              row("New games trend (30d vs prev 30d)") { games_vs_prev_30d }
              row("Installed games") { number.call(games_installed) }
              row("Favorite games") { number.call(games_favorite) }
              row("Games with notes") { number.call(games_with_notes) }
              row("Average games per user") { avg_games_per_user }
            end
          end
        end
      end

      columns do
        column do
          panel "Top Users by Sync Jobs (30 days)" do
            if top_sync_users.any?
              table_for top_sync_users do
                column("User") { |user| link_to(user.email, admin_user_path(user)) }
                column("Sync jobs") { |user| number.call(user.read_attribute(:sync_jobs_count).to_i) }
                column("Last sign-in") { |user| user.last_sign_in_at&.strftime("%Y-%m-%d %H:%M") || "Never" }
              end
            else
              para "No sync activity yet."
            end
          end
        end

        column do
          panel "Top Users by Added Games (30 days)" do
            if top_games_added_users.any?
              table_for top_games_added_users do
                column("User") { |user| link_to(user.email, admin_user_path(user)) }
                column("Games added") { |user| number.call(user.read_attribute(:games_added_count).to_i) }
                column("Total games now") { |user| number.call(user.games.count) }
              end
            else
              para "No game additions in the last 30 days."
            end
          end
        end
      end
    end
  end
end
