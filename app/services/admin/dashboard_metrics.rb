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
        "admin/dashboard_metrics/v5",
        as_of.to_i / CACHE_TTL
      ]
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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

      sync_metrics = build_sync_metrics
      sync_jobs_30d = sync_metrics[:sync_jobs_30d]

      users_active_both_30d = User.where(id: sync_jobs_30d.select(:user_id).distinct, last_sign_in_at: window_30_days).count
      users_sync_only_30d = [sync_metrics[:sync_active_users_30d] - users_active_both_30d, 0].max
      users_sign_in_only_30d = [users_active_sign_in_30d - users_active_both_30d, 0].max
      users_with_sign_in_no_sync_30d = users_sign_in_only_30d
      users_with_sync_no_games_added_30d = User.where(id: sync_jobs_30d.select(:user_id).distinct)
                                               .where.not(id: Game.where(created_at: window_30_days).select(:user_id).distinct)
                                               .count

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
      new_users_30d_scope = User.where(created_at: window_30_days)
      new_users_synced_24h_30d = users_with_first_sync_within(new_users_30d_scope, 1).count
      new_users_synced_7d_30d = users_with_first_sync_within(new_users_30d_scope, 7).count
      new_users_sync_24h_rate_30d = percentage(new_users_synced_24h_30d, users_new_30d)
      new_users_sync_7d_rate_30d = percentage(new_users_synced_7d_30d, users_new_30d)

      deleting_users_scope = User.where(deleting: true)
      deleting_users_count = deleting_users_scope.count
      oldest_deletion_requested_at = deleting_users_scope.minimum(:deletion_requested_at)

      sync_backlog_scope = SyncJob.where(status: %w[queued running])
      sync_backlog_count = sync_backlog_scope.count
      oldest_queued_sync_at = SyncJob.where(status: "queued").minimum(:created_at)

      sync_jobs_24h = SyncJob.where(created_at: 24.hours.ago..as_of)
      sync_status_counts_24h = sync_jobs_24h.group(:status).count
      sync_finished_24h = sync_status_counts_24h.fetch("finished", 0)
      sync_failed_24h = sync_status_counts_24h.fetch("failed", 0)
      sync_dead_24h = sync_status_counts_24h.fetch("dead", 0)
      sync_terminal_count_24h = sync_finished_24h + sync_failed_24h + sync_dead_24h
      sync_failed_rate_24h = if sync_terminal_count_24h.zero?
                               "N/A"
                             else
                               "#{(((sync_failed_24h + sync_dead_24h).to_f / sync_terminal_count_24h) * 100).round(1)}%"
                             end

      sync_processing_percentiles = sync_jobs_30d.where.not(processing_time: nil).pick(
        Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY processing_time)"),
        Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_time)")
      )
      sync_processing_p50 = sync_processing_percentiles&.first&.to_f&.round(2)
      sync_processing_p95 = sync_processing_percentiles&.last&.to_f&.round(2)

      signup_to_first_sync_days = User.where(created_at: window_30_days)
                                      .joins(<<~SQL.squish)
                                        INNER JOIN (
                                          SELECT user_id, MIN(created_at) AS first_sync_at
                                          FROM sync_jobs
                                          GROUP BY user_id
                                        ) first_sync ON first_sync.user_id = users.id
                                      SQL
                                      .pluck(Arel.sql("EXTRACT(EPOCH FROM (first_sync.first_sync_at - users.created_at)) / 86400.0"))
      median_signup_to_first_sync_days = median(signup_to_first_sync_days)&.round(2)

      first_sync_to_first_game_days = User.joins(<<~SQL.squish)
                                  INNER JOIN (
                                    SELECT user_id, MIN(created_at) AS first_sync_at
                                    FROM sync_jobs
                                    GROUP BY user_id
                                  ) first_sync ON first_sync.user_id = users.id
                                  INNER JOIN (
                                    SELECT user_id, MIN(created_at) AS first_game_at
                                    FROM games
                                    GROUP BY user_id
                                  ) first_game ON first_game.user_id = users.id
                                SQL
                                  .where("first_sync.first_sync_at >= ? AND first_sync.first_sync_at <= ?", window_30_days.begin, window_30_days.end)
                                  .pluck(Arel.sql("EXTRACT(EPOCH FROM (first_game.first_game_at - first_sync.first_sync_at)) / 86400.0"))
      median_first_sync_to_first_game_days = median(first_sync_to_first_game_days)&.round(2)

      {
        users_total:,
        users_new_30d:,
        users_new_prev_30d:,
        users_confirmed_total:,
        users_confirmed_30d:,
        users_active_sign_in_30d:,
        sync_events_30d: sync_metrics[:sync_events_30d],
        sync_events_prev_30d: sync_metrics[:sync_events_prev_30d],
        sync_active_users_30d: sync_metrics[:sync_active_users_30d],
        sync_finished_30d: sync_metrics[:sync_finished_30d],
        sync_failed_30d: sync_metrics[:sync_failed_30d],
        sync_dead_30d: sync_metrics[:sync_dead_30d],
        sync_running_30d: sync_metrics[:sync_running_30d],
        sync_avg_processing_time: sync_metrics[:sync_avg_processing_time],
        sync_success_rate: sync_metrics[:sync_success_rate],
        chunked_sync_jobs_30d: sync_metrics[:chunked_sync_jobs_30d],
        chunked_sync_requests_30d: sync_metrics[:chunked_sync_requests_30d],
        avg_chunks_per_request_30d: sync_metrics[:avg_chunks_per_request_30d],
        max_chunks_per_request_30d: sync_metrics[:max_chunks_per_request_30d],
        sync_payload_bytes_30d: sync_metrics[:sync_payload_bytes_30d],
        sync_payload_bytes_prev_30d: sync_metrics[:sync_payload_bytes_prev_30d],
        sync_avg_payload_size_bytes: sync_metrics[:sync_avg_payload_size_bytes],
        sync_games_30d: sync_metrics[:sync_games_30d],
        sync_games_prev_30d: sync_metrics[:sync_games_prev_30d],
        sync_avg_games_per_job: sync_metrics[:sync_avg_games_per_job],
        deleting_users_count:,
        oldest_deletion_requested_at:,
        sync_backlog_count:,
        oldest_queued_sync_at:,
        sync_failed_rate_24h:,
        sync_processing_p50:,
        sync_processing_p95:,
        users_with_sign_in_no_sync_30d:,
        users_with_sync_no_games_added_30d:,
        median_signup_to_first_sync_days:,
        median_first_sync_to_first_game_days:,
        new_users_synced_24h_30d:,
        new_users_synced_7d_30d:,
        new_users_sync_24h_rate_30d:,
        new_users_sync_7d_rate_30d:,
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
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def build_sync_metrics
      sync_jobs_30d = SyncJob.where(created_at: window_30_days)
      sync_jobs_prev_30d = SyncJob.where(created_at: previous_30_days)
      sync_status_counts_30d = sync_jobs_30d.group(:status).count
      sync_finished_30d = sync_status_counts_30d.fetch("finished", 0)
      sync_failed_30d = sync_status_counts_30d.fetch("failed", 0)
      sync_dead_30d = sync_status_counts_30d.fetch("dead", 0)
      sync_running_30d = sync_status_counts_30d.fetch("running", 0)
      chunked_requests_scope = sync_jobs_30d.where(payload_chunk_index: 0).where("COALESCE(payload_chunks, 1) > 1")
      sync_payload_bytes_30d = sync_jobs_30d.where.not(payload_size_bytes: nil).sum(:payload_size_bytes).to_i
      sync_payload_bytes_prev_30d = sync_jobs_prev_30d.where.not(payload_size_bytes: nil).sum(:payload_size_bytes).to_i
      sync_avg_payload_size_bytes = sync_jobs_30d.where.not(payload_size_bytes: nil).average(:payload_size_bytes)&.to_f&.round || 0

      if SyncJob.columns_hash.key?("games_count")
        sync_games_30d = sync_jobs_30d.where.not(games_count: nil).sum(:games_count).to_i
        sync_games_prev_30d = sync_jobs_prev_30d.where.not(games_count: nil).sum(:games_count).to_i
        sync_avg_games_per_job = sync_jobs_30d.where.not(games_count: nil).average(:games_count)&.to_f&.round(2)
      else
        sync_games_30d = 0
        sync_games_prev_30d = 0
        sync_avg_games_per_job = nil
      end

      {
        sync_jobs_30d:,
        sync_events_30d: sync_status_counts_30d.values.sum,
        sync_events_prev_30d: sync_jobs_prev_30d.group(:status).count.values.sum,
        sync_active_users_30d: sync_jobs_30d.select(:user_id).distinct.count,
        sync_finished_30d:,
        sync_failed_30d:,
        sync_dead_30d:,
        sync_running_30d:,
        sync_avg_processing_time: sync_jobs_30d.where.not(processing_time: nil).average(:processing_time)&.round(2),
        sync_success_rate: sync_success_rate(sync_finished_30d, sync_failed_30d, sync_dead_30d),
        chunked_sync_jobs_30d: sync_jobs_30d.where("COALESCE(payload_chunks, 1) > 1").count,
        chunked_sync_requests_30d: chunked_requests_scope.count,
        avg_chunks_per_request_30d: chunked_requests_scope.average(:payload_chunks)&.to_f&.round(2),
        max_chunks_per_request_30d: chunked_requests_scope.maximum(:payload_chunks)&.to_i,
        sync_payload_bytes_30d:,
        sync_payload_bytes_prev_30d:,
        sync_avg_payload_size_bytes:,
        sync_games_30d:,
        sync_games_prev_30d:,
        sync_avg_games_per_job:
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def sync_success_rate(sync_finished_30d, sync_failed_30d, sync_dead_30d)
      sync_terminal_count = sync_finished_30d + sync_failed_30d + sync_dead_30d
      return "N/A" if sync_terminal_count.zero?

      "#{((sync_finished_30d.to_f / sync_terminal_count) * 100).round(1)}%"
    end

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

    def users_with_first_sync_within(scope, days)
      scope.joins(<<~SQL.squish)
        INNER JOIN sync_jobs sync_conversion
          ON sync_conversion.user_id = users.id
         AND sync_conversion.created_at >= users.created_at
         AND sync_conversion.created_at <= users.created_at + interval '#{days} days'
      SQL
           .distinct
    end

    def percentage(value, total)
      return "N/A" if total.to_i.zero?

      "#{((value.to_f / total) * 100).round(1)}%"
    end

    def median(values)
      clean = values.compact.map(&:to_f).sort
      return nil if clean.empty?

      middle = clean.length / 2
      if clean.length.odd?
        clean[middle]
      else
        (clean[middle - 1] + clean[middle]) / 2.0
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
