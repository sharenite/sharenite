# frozen_string_literal: true

module Admin
  # Aggregates dashboard metrics with short-lived caching.
  # rubocop:disable Metrics/ClassLength
  class DashboardMetrics
    CACHE_TTL = 10.minutes

    class << self
      def call(as_of: Time.current)
        new(as_of:).call
      end
    end

    def initialize(as_of:)
      @as_of = as_of
      @window_30_days = 30.days.ago..as_of
      @previous_30_days = 60.days.ago...30.days.ago
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, race_condition_ttl: 30.seconds) { compute_metrics }
    end

    private

    attr_reader :as_of, :window_30_days, :previous_30_days

    def cache_key
      [
        "admin/dashboard_metrics/v3",
        as_of.to_i / CACHE_TTL
      ]
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def compute_metrics
      users_total, users_new_30d, users_new_prev_30d, users_confirmed_total, users_confirmed_30d, users_active_sign_in_30d =
        User.pick(
          Arel.sql("COUNT(*)"),
          Arel.sql(range_count_sql("created_at", window_30_days)),
          Arel.sql(range_count_sql("created_at", previous_30_days)),
          Arel.sql("COUNT(*) FILTER (WHERE confirmed_at IS NOT NULL)"),
          Arel.sql(range_count_sql("confirmed_at", window_30_days)),
          Arel.sql(range_count_sql("last_sign_in_at", window_30_days))
        ).map(&:to_i)

      sync_jobs_30d = SyncJob.where(created_at: window_30_days)
      sync_jobs_prev_30d = SyncJob.where(created_at: previous_30_days)
      sync_status_counts_30d = sync_jobs_30d.group(:status).count
      sync_events_30d = sync_status_counts_30d.values.sum
      sync_active_users_30d = sync_jobs_30d.select(:user_id).distinct.count
      sync_finished_30d = sync_status_counts_30d.fetch("finished", 0)
      sync_failed_30d = sync_status_counts_30d.fetch("failed", 0)
      sync_dead_30d = sync_status_counts_30d.fetch("dead", 0)
      sync_running_30d = sync_status_counts_30d.fetch("running", 0)
      sync_events_prev_30d = sync_jobs_prev_30d.group(:status).count.values.sum
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

      games_total, games_new_30d, games_new_prev_30d, games_with_recent_activity, games_installed, games_favorite, games_with_notes =
        Game.pick(
          Arel.sql("COUNT(*)"),
          Arel.sql(range_count_sql("created_at", window_30_days)),
          Arel.sql(range_count_sql("created_at", previous_30_days)),
          Arel.sql(range_count_sql("last_activity", window_30_days)),
          Arel.sql("COUNT(*) FILTER (WHERE is_installed = TRUE)"),
          Arel.sql("COUNT(*) FILTER (WHERE favorite = TRUE)"),
          Arel.sql("COUNT(*) FILTER (WHERE notes IS NOT NULL AND notes != '')")
        ).map(&:to_i)
      avg_games_per_user = users_total.zero? ? 0 : (games_total.to_f / users_total).round(2)

      top_sync_users = User.joins(:sync_jobs)
                           .where(sync_jobs: { created_at: window_30_days })
                           .select("users.*, COUNT(sync_jobs.id) AS sync_jobs_count")
                           .group("users.id")
                           .order("sync_jobs_count DESC")
                           .limit(8)

      top_games_added_users = User.joins(:games)
                                  .where(games: { created_at: window_30_days })
                                  .select(
                                    "users.*, COUNT(games.id) AS games_added_count, " \
                                    "#{total_games_count_sql} AS total_games_count"
                                  )
                                  .group("users.id")
                                  .order("games_added_count DESC")
                                  .limit(8)

      {
        users_total:,
        users_new_30d:,
        users_new_prev_30d:,
        users_confirmed_total:,
        users_confirmed_30d:,
        users_active_sign_in_30d:,
        sync_events_30d:,
        sync_events_prev_30d:,
        sync_active_users_30d:,
        sync_finished_30d:,
        sync_failed_30d:,
        sync_dead_30d:,
        sync_running_30d:,
        sync_avg_processing_time:,
        sync_success_rate:,
        users_active_both_30d:,
        users_sync_only_30d:,
        users_sign_in_only_30d:,
        games_total:,
        games_new_30d:,
        games_new_prev_30d:,
        games_with_recent_activity:,
        games_installed:,
        games_favorite:,
        games_with_notes:,
        avg_games_per_user:,
        top_sync_users: top_sync_users.to_a,
        top_games_added_users: top_games_added_users.to_a
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def range_count_sql(column_name, range)
      from = ActiveRecord::Base.connection.quote(range.begin)
      to = ActiveRecord::Base.connection.quote(range.end)
      upper_bound_operator = range.exclude_end? ? "<" : "<="
      "COUNT(*) FILTER (WHERE #{column_name} >= #{from} AND #{column_name} #{upper_bound_operator} #{to})"
    end

    def total_games_count_sql
      if User.games_count_available?
        "users.games_count"
      else
        "(SELECT COUNT(*) FROM games all_games WHERE all_games.user_id = users.id)"
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
