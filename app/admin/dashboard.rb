# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    metrics = Admin::DashboardMetrics.call

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

    users_vs_prev_30d = percent_change.call(metrics[:users_new_30d], metrics[:users_new_prev_30d])
    games_vs_prev_30d = percent_change.call(metrics[:games_new_30d], metrics[:games_new_prev_30d])
    sync_events_vs_prev_30d = percent_change.call(metrics[:sync_events_30d], metrics[:sync_events_prev_30d])

    div class: "admin-dashboard" do
      div class: "admin-dashboard-kpis" do
        div class: "admin-kpi-card" do
          div "Total users", class: "admin-kpi-label"
          div number.call(metrics[:users_total]), class: "admin-kpi-value"
          div "Confirmed: #{number.call(metrics[:users_confirmed_total])}", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "New users (30d)", class: "admin-kpi-label"
          div number.call(metrics[:users_new_30d]), class: "admin-kpi-value"
          span users_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(users_vs_prev_30d)}"
        end
        div class: "admin-kpi-card" do
          div "Active users (30d)", class: "admin-kpi-label"
          div number.call(metrics[:users_active_sign_in_30d]), class: "admin-kpi-value"
          div "Sync-active: #{number.call(metrics[:sync_active_users_30d])}", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "Total games", class: "admin-kpi-label"
          div number.call(metrics[:games_total]), class: "admin-kpi-value"
          div "Installed: #{number.call(metrics[:games_installed])}", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "New games (30d)", class: "admin-kpi-label"
          div number.call(metrics[:games_new_30d]), class: "admin-kpi-value"
          span games_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(games_vs_prev_30d)}"
        end
        div class: "admin-kpi-card" do
          div "Sync success rate", class: "admin-kpi-label"
          div metrics[:sync_success_rate], class: "admin-kpi-value"
          div "Avg processing: #{metrics[:sync_avg_processing_time] || 'N/A'}s", class: "admin-kpi-meta"
        end
        div class: "admin-kpi-card" do
          div "Sync events (30d)", class: "admin-kpi-label"
          div number.call(metrics[:sync_events_30d]), class: "admin-kpi-value"
          span sync_events_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(sync_events_vs_prev_30d)}"
        end
        div class: "admin-kpi-card" do
          div "Chunked sync requests (30d)", class: "admin-kpi-label"
          div number.call(metrics[:chunked_sync_requests_30d]), class: "admin-kpi-value"
          div "Chunk jobs: #{number.call(metrics[:chunked_sync_jobs_30d])}", class: "admin-kpi-meta"
        end
      end

      columns do
        column do
          panel "Users Overview" do
            attributes_table_for :users do
              row("Total users") { number.call(metrics[:users_total]) }
              row("Confirmed users") { number.call(metrics[:users_confirmed_total]) }
              row("New users (30d)") { number.call(metrics[:users_new_30d]) }
              row("New users (prev 30d)") { number.call(metrics[:users_new_prev_30d]) }
              row("New users trend (30d vs prev 30d)") { users_vs_prev_30d }
              row("Confirmed users (30d)") { number.call(metrics[:users_confirmed_30d]) }
            end
          end
        end

        column do
          panel "Sync Jobs Health (30 days)" do
            attributes_table_for :sync_jobs do
              row("Finished") { number.call(metrics[:sync_finished_30d]) }
              row("Failed") { number.call(metrics[:sync_failed_30d]) }
              row("Dead") { number.call(metrics[:sync_dead_30d]) }
              row("Running") { number.call(metrics[:sync_running_30d]) }
              row("Success rate (finished/(finished+failed+dead))") { metrics[:sync_success_rate] }
              row("Avg processing time (s)") { metrics[:sync_avg_processing_time] || "N/A" }
              row("Chunked requests") { number.call(metrics[:chunked_sync_requests_30d]) }
              row("Chunk jobs") { number.call(metrics[:chunked_sync_jobs_30d]) }
              row("Avg chunks per chunked request") { metrics[:avg_chunks_per_request_30d] || "N/A" }
              row("Max chunks in one request") { metrics[:max_chunks_per_request_30d] || "N/A" }
              row("Total chunk payload (30d)") { helpers.number_to_human_size(metrics[:sync_payload_bytes_30d]) }
            end
          end
        end
      end

      columns do
        column do
          panel "Activity Correlation (30 days)" do
            attributes_table_for :activity do
              row("Users active by sign-in") { number.call(metrics[:users_active_sign_in_30d]) }
              row("Users active by sync job") { number.call(metrics[:sync_active_users_30d]) }
              row("Games with activity") { number.call(metrics[:games_with_recent_activity]) }
              row("Active in both (sign-in + sync)") { number.call(metrics[:users_active_both_30d]) }
              row("Sign-in only") { number.call(metrics[:users_sign_in_only_30d]) }
              row("Sync-only") { number.call(metrics[:users_sync_only_30d]) }
            end
            para "Useful to compare auth activity, sync activity, and actual game engagement."
          end
        end

        column do
          panel "Games Overview" do
            attributes_table_for :games do
              row("Total games") { number.call(metrics[:games_total]) }
              row("New games (30d)") { number.call(metrics[:games_new_30d]) }
              row("New games (prev 30d)") { number.call(metrics[:games_new_prev_30d]) }
              row("New games trend (30d vs prev 30d)") { games_vs_prev_30d }
              row("Installed games") { number.call(metrics[:games_installed]) }
              row("Favorite games") { number.call(metrics[:games_favorite]) }
              row("Games with notes") { number.call(metrics[:games_with_notes]) }
              row("Average games per user") { metrics[:avg_games_per_user] }
            end
          end
        end
      end

      columns do
        column do
          panel "Top Users by Sync Jobs (30 days)" do
            if metrics[:top_sync_users].any?
              table_for metrics[:top_sync_users] do
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
            if metrics[:top_games_added_users].any?
              table_for metrics[:top_games_added_users] do
                column("User") { |user| link_to(user.email, admin_user_path(user)) }
                column("Games added") { |user| number.call(user.read_attribute(:games_added_count).to_i) }
                column("Total games now") { |user| number.call(user.read_attribute(:total_games_count).to_i) }
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
