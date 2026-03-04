# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    if params[:dashboard_refresh] == "1"
      Admin::DashboardMetrics.clear_cache!
    end
    force_refresh = params[:dashboard_no_cache] == "1" || params[:dashboard_refresh] == "1"
    metrics = Admin::DashboardMetrics.call(force_refresh:)

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
    metric_tone = lambda do |value, good_if_zero: false, good_if_hundred: false|
      numeric =
        case value
        when String
          value.delete("%").to_f
        else
          value.to_f
        end

      if good_if_zero
        numeric.zero? ? "is-good" : "is-bad"
      elsif good_if_hundred
        numeric >= 99.9 ? "is-good" : "is-bad"
      else
        "is-neutral"
      end
    end
    toned_text = lambda do |text, tone|
      status_tag(text, class: "admin-health-value #{tone}")
    end
    human_duration = lambda do |seconds|
      return "N/A" if seconds.blank?

      total_seconds = seconds.to_i
      minutes = total_seconds / 60
      remaining_seconds = total_seconds % 60
      if minutes.positive?
        "#{minutes}m #{remaining_seconds}s"
      else
        "#{remaining_seconds}s"
      end
    end
    number = ->(value) { helpers.number_with_delimiter(value) }
    human_size = ->(bytes) { helpers.number_to_human_size(bytes, precision: 2) }

    users_vs_prev_30d = percent_change.call(metrics[:users_new_30d], metrics[:users_new_prev_30d])
    games_vs_prev_30d = percent_change.call(metrics[:games_new_30d], metrics[:games_new_prev_30d])
    sync_events_vs_prev_30d = percent_change.call(metrics[:sync_events_30d], metrics[:sync_events_prev_30d])
    failed_requests_vs_prev_30d = percent_change.call(metrics[:sync_failed_requests_30d], metrics[:sync_failed_requests_prev_30d])
    sync_games_vs_prev_30d = percent_change.call(metrics[:sync_games_30d], metrics[:sync_games_prev_30d])
    oldest_deletion_age = if metrics[:oldest_deletion_requested_at].present?
                            helpers.time_ago_in_words(metrics[:oldest_deletion_requested_at])
                          else
                            "N/A"
                          end
    oldest_queue_age = if metrics[:oldest_queued_sync_at].present?
                         helpers.time_ago_in_words(metrics[:oldest_queued_sync_at])
                       else
                         "N/A"
                       end
    dashboard_refreshed_at = metrics[:dashboard_refreshed_at]
    dashboard_refresh_text = if dashboard_refreshed_at.present?
                               "#{helpers.time_ago_in_words(dashboard_refreshed_at)} ago " \
                                 "(#{dashboard_refreshed_at.strftime('%Y-%m-%d %H:%M:%S %Z')})"
                             else
                               "N/A"
                             end
    latest_sync_event_age = if metrics[:latest_sync_event_at].present?
                              helpers.time_ago_in_words(metrics[:latest_sync_event_at])
                            else
                              "N/A"
                            end
    sync_health_state = begin
      slow_requests = metrics[:slow_requests_over_900s_30d].to_i
      backlog = metrics[:sync_backlog_count].to_i
      request_success = metrics[:sync_request_success_rate].to_s.delete("%").to_f
      if slow_requests.positive? || backlog > 25 || request_success < 99.0
        { label: "Attention", tone: "is-bad" }
      elsif backlog.positive? || request_success < 100.0
        { label: "Watch", tone: "is-neutral" }
      else
        { label: "Healthy", tone: "is-good" }
      end
    end
    p95_request_processing = metrics[:sync_request_processing_p95]
    request_processing_sample_size = metrics[:sync_request_processing_sample_size].to_i

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
          div metrics[:sync_success_rate], class: "admin-kpi-value #{metric_tone.call(metrics[:sync_success_rate], good_if_hundred: true)}"
          div "Request success: #{metrics[:sync_request_success_rate]}", class: "admin-kpi-meta"
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
        div class: "admin-kpi-card" do
          div "Failed requests (30d)", class: "admin-kpi-label"
          div number.call(metrics[:sync_failed_requests_30d]),
              class: "admin-kpi-value #{metric_tone.call(metrics[:sync_failed_requests_30d], good_if_zero: true)}"
          p95_meta = "p95 req proc: #{human_duration.call(p95_request_processing)}"
          p95_meta = "#{p95_meta} (n=#{number.call(request_processing_sample_size)})" if request_processing_sample_size.positive?
          div p95_meta, class: "admin-kpi-meta"
          span failed_requests_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(failed_requests_vs_prev_30d)}"
        end
        div class: "admin-kpi-card" do
          div "Synced games (30d)", class: "admin-kpi-label"
          div number.call(metrics[:sync_games_30d]), class: "admin-kpi-value"
          span sync_games_vs_prev_30d, class: "admin-kpi-trend #{trend_class.call(sync_games_vs_prev_30d)}"
        end
      end

      div class: "admin-dashboard-refresh-note" do
        strong "Last dashboard refresh: "
        text_node dashboard_refresh_text
        text_node " "
        refresh_params = request.query_parameters.except("dashboard_refresh", "dashboard_no_cache")
        text_node(link_to("Refresh now", admin_root_path(refresh_params.merge(dashboard_refresh: "1")), class: "admin-dashboard-refresh-link"))
        text_node " | "
        if params[:dashboard_no_cache] == "1"
          text_node(link_to("Back to cached", admin_root_path(refresh_params), class: "admin-dashboard-refresh-link"))
        else
          text_node(link_to("Bypass cache", admin_root_path(refresh_params.merge(dashboard_no_cache: "1")), class: "admin-dashboard-refresh-link"))
        end
      end

      div class: "admin-dashboard-panels" do
        panel "Users Overview" do
          attributes_table_for :users do
            row("Total users") { number.call(metrics[:users_total]) }
            row("Confirmed users") { number.call(metrics[:users_confirmed_total]) }
            row("New users (30d)") { number.call(metrics[:users_new_30d]) }
            row("New users (prev 30d)") { number.call(metrics[:users_new_prev_30d]) }
            row("New users trend (30d vs prev 30d)") { users_vs_prev_30d }
            row("New users first sync <=24h (30d)") { number.call(metrics[:new_users_synced_24h_30d]) }
            row("New users first sync <=7d (30d)") { number.call(metrics[:new_users_synced_7d_30d]) }
            row("User-to-sync conversion <=24h (30d)") { metrics[:new_users_sync_24h_rate_30d] }
            row("User-to-sync conversion <=7d (30d)") { metrics[:new_users_sync_7d_rate_30d] }
            row("Confirmed users (30d)") { number.call(metrics[:users_confirmed_30d]) }
            row("Oldest deletion request age") { oldest_deletion_age }
            row("Deleted users (30d)") { number.call(metrics[:deleted_users_30d]) }
            row("Median deletion job time (s)") { metrics[:median_deletion_job_seconds_30d] || "N/A" }
          end
        end

        panel "Sync Jobs Health (30 days)" do
          div class: "admin-sync-health-status" do
            text_node "Status: "
            span title: "Attention: slow>0 or backlog>25 or req success<99%. Watch: backlog>0 or req success<100%" do
              toned_text.call(sync_health_state[:label], sync_health_state[:tone])
            end
            span "?", class: "admin-sync-health-status-hint", title: "Attention: slow>0 or backlog>25 or req success<99%. Watch: backlog>0 or req success<100%"
          end
          sync_health_tab = params[:sync_health_tab] == "requests" ? "requests" : "jobs"
          base_params = request.query_parameters.except("sync_health_tab")

          div class: "admin-sync-health-tabs" do
            div class: "admin-sync-health-nav" do
              text_node(
                link_to(
                  "Jobs",
                  admin_root_path(base_params.merge(sync_health_tab: "jobs")),
                  class: "admin-sync-health-nav-link #{'is-active' if sync_health_tab == 'jobs'}"
                )
              )
              text_node(
                link_to(
                  "Requests",
                  admin_root_path(base_params.merge(sync_health_tab: "requests")),
                  class: "admin-sync-health-nav-link #{'is-active' if sync_health_tab == 'requests'}"
                )
              )
            end

            if sync_health_tab == "jobs"
              div class: "admin-sync-health-tab-content" do
                div class: "admin-sync-health-grid" do
                  div class: "admin-sync-health-col" do
                    attributes_table_for :sync_jobs_core_primary do
                      row("Finished") { number.call(metrics[:sync_finished_30d]) }
                      row("Failed") { number.call(metrics[:sync_failed_30d]) }
                      row("Dead") { number.call(metrics[:sync_dead_30d]) }
                      row("Running") { number.call(metrics[:sync_running_30d]) }
                      row("Success rate") do
                        toned_text.call(
                          metrics[:sync_success_rate],
                          metric_tone.call(metrics[:sync_success_rate], good_if_hundred: true)
                        )
                      end
                      row("Failed chunks (30d)") { number.call(metrics[:sync_failed_chunks_30d]) }
                      row("Failed rate (24h)") do
                        toned_text.call(
                          metrics[:sync_failed_rate_24h],
                          metric_tone.call(metrics[:sync_failed_rate_24h], good_if_zero: true)
                        )
                      end
                      row("Backlog (queued + running)") { number.call(metrics[:sync_backlog_count]) }
                      row("Oldest queued age") { oldest_queue_age }
                      row("Last sync event age") { latest_sync_event_age }
                    end
                  end

                  div class: "admin-sync-health-col" do
                    attributes_table_for :sync_jobs_core_performance do
                      row("Avg processing time (s)") { metrics[:sync_avg_processing_time] || "N/A" }
                      row("p50 processing latency (s)") { metrics[:sync_processing_p50] || "N/A" }
                      row("p95 processing latency (s)") { metrics[:sync_processing_p95] || "N/A" }
                      row("p50 waiting time (s)") { metrics[:sync_waiting_p50] || "N/A" }
                      row("p95 waiting time (s)") { metrics[:sync_waiting_p95] || "N/A" }
                      row("p50 processing latency (1st chunk, s)") { metrics[:sync_processing_p50_first_chunk] || "N/A" }
                      row("p95 processing latency (1st chunk, s)") { metrics[:sync_processing_p95_first_chunk] || "N/A" }
                      row("Avg processing time for 1000-game chunks (s)") do
                        metrics[:sync_avg_processing_time_per_1000_games] || "N/A"
                      end
                      row("Payload size avg/job (30d)") { human_size.call(metrics[:sync_avg_payload_size_bytes]) }
                      row("Synced games avg/job (30d)") { metrics[:sync_avg_games_per_job] || "N/A" }
                    end
                  end
                end
              end
            else
              div class: "admin-sync-health-tab-content" do
                div class: "admin-sync-health-grid" do
                  div class: "admin-sync-health-col" do
                    attributes_table_for :sync_requests_primary do
                      row("Total sync requests (30d)") { number.call(metrics[:sync_requests_30d]) }
                      row("Chunked requests") { number.call(metrics[:chunked_sync_requests_30d]) }
                      row("Request success rate") do
                        toned_text.call(
                          metrics[:sync_request_success_rate],
                          metric_tone.call(metrics[:sync_request_success_rate], good_if_hundred: true)
                        )
                      end
                      row("Failed requests (30d)") do
                        toned_text.call(
                          number.call(metrics[:sync_failed_requests_30d]),
                          metric_tone.call(metrics[:sync_failed_requests_30d], good_if_zero: true)
                        )
                      end
                      row("Slow requests >900s (30d)") do
                        span title: "Threshold: request total processing time > 900 seconds" do
                          status_tag(
                            number.call(metrics[:slow_requests_over_900s_30d]),
                            class: "admin-health-value #{metric_tone.call(metrics[:slow_requests_over_900s_30d], good_if_zero: true)}"
                          )
                        end
                      end
                      row("Requests per active sync user (30d)") { metrics[:sync_requests_per_active_user_30d] || "N/A" }
                      row("Synced games total (30d)") { number.call(metrics[:sync_games_30d]) }
                      row("Synced games avg/request (30d)") { metrics[:sync_avg_games_per_request] || "N/A" }
                      row("Payload size total (30d)") { human_size.call(metrics[:sync_payload_bytes_30d]) }
                      row("Payload size avg/request (30d)") do
                        avg_payload_size_per_request = metrics[:sync_avg_payload_size_per_request_bytes]
                        avg_payload_size_per_request.present? ? human_size.call(avg_payload_size_per_request) : "N/A"
                      end
                    end
                  end

                  div class: "admin-sync-health-col" do
                    attributes_table_for :sync_requests_distribution do
                      row("Avg request total processing time (s)") { metrics[:sync_avg_request_total_processing_time] || "N/A" }
                      row("p50 request processing time (s)") do
                        value = metrics[:sync_request_processing_p50] || "N/A"
                        request_processing_sample_size.positive? ? "#{value} (n=#{number.call(request_processing_sample_size)})" : value
                      end
                      row("p95 request processing time (s)") do
                        value = metrics[:sync_request_processing_p95] || "N/A"
                        request_processing_sample_size.positive? ? "#{value} (n=#{number.call(request_processing_sample_size)})" : value
                      end
                      row("p50 request waiting time (s)") { metrics[:sync_request_waiting_p50] || "N/A" }
                      row("p95 request waiting time (s)") { metrics[:sync_request_waiting_p95] || "N/A" }
                      row("Avg chunks per chunked request") { metrics[:avg_chunks_per_request_30d] || "N/A" }
                      row("p95 chunks per request") { metrics[:p95_chunks_per_request_30d] || "N/A" }
                      row("Chunk spread stddev") { metrics[:stddev_chunks_per_request_30d] || "N/A" }
                      row("Max chunks in one request") { metrics[:max_chunks_per_request_30d] || "N/A" }
                    end
                  end
                end
              end
            end
          end
        end

        panel "Activity Correlation (30 days)" do
          attributes_table_for :activity do
            row("Users active by sign-in") { number.call(metrics[:users_active_sign_in_30d]) }
            row("Users active by sync job") { number.call(metrics[:sync_active_users_30d]) }
            row("Games with activity") { number.call(metrics[:games_with_recent_activity]) }
            row("Active in both (sign-in + sync)") { number.call(metrics[:users_active_both_30d]) }
            row("Sign-in only") { number.call(metrics[:users_sign_in_only_30d]) }
            row("Sync-only") { number.call(metrics[:users_sync_only_30d]) }
            row("Users with sign-in but 0 sync jobs") { number.call(metrics[:users_with_sign_in_no_sync_30d]) }
            row("Users with sync jobs but 0 games added") { number.call(metrics[:users_with_sync_no_games_added_30d]) }
            row("Median signup -> first sync (days)") do
              value = metrics[:median_signup_to_first_sync_days]
              sample_size = metrics[:signup_to_first_sync_sample_size].to_i
              value.present? ? "#{value} (n=#{number.call(sample_size)})" : "N/A (n=0)"
            end
            row("Median signup -> first sync <=1d (days)") do
              value = metrics[:median_signup_to_first_sync_under_1d_days]
              sample_size = metrics[:signup_to_first_sync_under_1d_sample_size].to_i
              value.present? ? "#{value} (n=#{number.call(sample_size)})" : "N/A (n=0)"
            end
            row("Median first sync -> first game added (days)") do
              value = metrics[:median_first_sync_to_first_game_days]
              sample_size = metrics[:first_sync_to_first_game_sample_size].to_i
              value.present? ? "#{value} (n=#{number.call(sample_size)})" : "N/A (n=0)"
            end
            row("Median first sync -> first game <=1d (days)") do
              value = metrics[:median_first_sync_to_first_game_under_1d_days]
              sample_size = metrics[:first_sync_to_first_game_under_1d_sample_size].to_i
              value.present? ? "#{value} (n=#{number.call(sample_size)})" : "N/A (n=0)"
            end
          end
          para "Useful to compare auth activity, sync activity, and actual game engagement."
        end

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
