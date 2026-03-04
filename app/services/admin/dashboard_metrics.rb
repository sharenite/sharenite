# frozen_string_literal: true

module Admin
  # Aggregates dashboard metrics with short-lived caching.
  # rubocop:disable Metrics/ClassLength
  class DashboardMetrics
    CACHE_TTL = 10.minutes

    class << self
      def call(as_of: Time.current, force_refresh: false)
        new(as_of:).call(force_refresh:)
      end

      def clear_cache!
        Rails.cache.delete_matched("admin/dashboard_metrics/*")
      rescue NotImplementedError
        nil
      end
    end

    def initialize(as_of:)
      @as_of = as_of
      @window_30_days = 30.days.ago..as_of
      @previous_30_days = 60.days.ago...30.days.ago
    end

    def call(force_refresh: false)
      return compute_metrics if force_refresh

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, race_condition_ttl: 30.seconds) { compute_metrics }
    end

    private

    attr_reader :as_of, :window_30_days, :previous_30_days

    def cache_key
      [
        "admin/dashboard_metrics/v10",
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
      deleted_users_30d_scope = UserDeletionEvent.succeeded.where(job_succeeded_at: window_30_days)
      deleted_users_30d = deleted_users_30d_scope.count
      deletion_job_durations_30d = deleted_users_30d_scope.where.not(job_started_at: nil)
                                                           .pluck(Arel.sql("EXTRACT(EPOCH FROM (job_succeeded_at - job_started_at))"))
      median_deletion_job_seconds_30d = median(deletion_job_durations_30d)&.round(2)

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

      signup_to_first_sync_days = User.where(created_at: window_30_days)
                                      .joins(<<~SQL.squish)
                                        INNER JOIN (
                                          SELECT user_id, MIN(created_at) AS first_sync_at
                                          FROM sync_jobs
                                          GROUP BY user_id
                                        ) first_sync ON first_sync.user_id = users.id
                                      SQL
                                      .where("first_sync.first_sync_at >= users.created_at")
                                      .pluck(Arel.sql("EXTRACT(EPOCH FROM (first_sync.first_sync_at - users.created_at)) / 86400.0"))
      median_signup_to_first_sync_days = median(signup_to_first_sync_days)&.round(2)
      signup_to_first_sync_sample_size = signup_to_first_sync_days.size
      signup_to_first_sync_under_1d_days = signup_to_first_sync_days.select { |days| days.to_f <= 1.0 }
      median_signup_to_first_sync_under_1d_days = median(signup_to_first_sync_under_1d_days)&.round(2)
      signup_to_first_sync_under_1d_sample_size = signup_to_first_sync_under_1d_days.size

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
                                  .where("first_game.first_game_at >= first_sync.first_sync_at")
                                  .pluck(Arel.sql("EXTRACT(EPOCH FROM (first_game.first_game_at - first_sync.first_sync_at)) / 86400.0"))
      median_first_sync_to_first_game_days = median(first_sync_to_first_game_days)&.round(2)
      first_sync_to_first_game_sample_size = first_sync_to_first_game_days.size
      first_sync_to_first_game_under_1d_days = first_sync_to_first_game_days.select { |days| days.to_f <= 1.0 }
      median_first_sync_to_first_game_under_1d_days = median(first_sync_to_first_game_under_1d_days)&.round(2)
      first_sync_to_first_game_under_1d_sample_size = first_sync_to_first_game_under_1d_days.size

      {
        dashboard_refreshed_at: as_of,
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
        sync_avg_processing_time_per_request: sync_metrics[:sync_avg_processing_time_per_request],
        sync_avg_request_total_processing_time: sync_metrics[:sync_avg_request_total_processing_time],
        sync_success_rate: sync_metrics[:sync_success_rate],
        sync_request_success_rate: sync_metrics[:sync_request_success_rate],
        sync_failed_chunks_30d: sync_metrics[:sync_failed_chunks_30d],
        sync_failed_requests_30d: sync_metrics[:sync_failed_requests_30d],
        sync_failed_requests_prev_30d: sync_metrics[:sync_failed_requests_prev_30d],
        chunked_sync_jobs_30d: sync_metrics[:chunked_sync_jobs_30d],
        chunked_sync_requests_30d: sync_metrics[:chunked_sync_requests_30d],
        sync_requests_30d: sync_metrics[:sync_requests_30d],
        avg_chunks_per_request_30d: sync_metrics[:avg_chunks_per_request_30d],
        p95_chunks_per_request_30d: sync_metrics[:p95_chunks_per_request_30d],
        stddev_chunks_per_request_30d: sync_metrics[:stddev_chunks_per_request_30d],
        max_chunks_per_request_30d: sync_metrics[:max_chunks_per_request_30d],
        sync_payload_bytes_30d: sync_metrics[:sync_payload_bytes_30d],
        sync_payload_bytes_prev_30d: sync_metrics[:sync_payload_bytes_prev_30d],
        sync_avg_payload_size_bytes: sync_metrics[:sync_avg_payload_size_bytes],
        sync_avg_payload_size_per_request_bytes: sync_metrics[:sync_avg_payload_size_per_request_bytes],
        sync_games_30d: sync_metrics[:sync_games_30d],
        sync_games_prev_30d: sync_metrics[:sync_games_prev_30d],
        sync_avg_games_per_job: sync_metrics[:sync_avg_games_per_job],
        sync_avg_games_per_request: sync_metrics[:sync_avg_games_per_request],
        sync_avg_processing_time_per_1000_games: sync_metrics[:sync_avg_processing_time_per_1000_games],
        slow_requests_over_900s_30d: sync_metrics[:slow_requests_over_900s_30d],
        latest_sync_event_at: sync_metrics[:latest_sync_event_at],
        sync_requests_per_active_user_30d: sync_metrics[:sync_requests_per_active_user_30d],
        deleting_users_count:,
        oldest_deletion_requested_at:,
        deleted_users_30d:,
        median_deletion_job_seconds_30d:,
        sync_backlog_count:,
        oldest_queued_sync_at:,
        sync_failed_rate_24h:,
        sync_processing_p50: sync_metrics[:sync_processing_p50],
        sync_processing_p95: sync_metrics[:sync_processing_p95],
        sync_request_processing_p50: sync_metrics[:sync_request_processing_p50],
        sync_request_processing_p95: sync_metrics[:sync_request_processing_p95],
        sync_request_processing_sample_size: sync_metrics[:sync_request_processing_sample_size],
        sync_processing_p50_first_chunk: sync_metrics[:sync_processing_p50_first_chunk],
        sync_processing_p95_first_chunk: sync_metrics[:sync_processing_p95_first_chunk],
        sync_waiting_p50: sync_metrics[:sync_waiting_p50],
        sync_waiting_p95: sync_metrics[:sync_waiting_p95],
        sync_request_waiting_p50: sync_metrics[:sync_request_waiting_p50],
        sync_request_waiting_p95: sync_metrics[:sync_request_waiting_p95],
        users_with_sign_in_no_sync_30d:,
        users_with_sync_no_games_added_30d:,
        median_signup_to_first_sync_days:,
        median_first_sync_to_first_game_days:,
        signup_to_first_sync_sample_size:,
        first_sync_to_first_game_sample_size:,
        median_signup_to_first_sync_under_1d_days:,
        median_first_sync_to_first_game_under_1d_days:,
        signup_to_first_sync_under_1d_sample_size:,
        first_sync_to_first_game_under_1d_sample_size:,
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
      sync_failed_chunks_30d = sync_failed_30d + sync_dead_30d
      sync_payload_bytes_30d = sync_jobs_30d.where.not(payload_size_bytes: nil).sum(:payload_size_bytes).to_i
      sync_payload_bytes_prev_30d = sync_jobs_prev_30d.where.not(payload_size_bytes: nil).sum(:payload_size_bytes).to_i
      sync_avg_payload_size_bytes = sync_jobs_30d.where.not(payload_size_bytes: nil).average(:payload_size_bytes)&.to_f&.round || 0
      processing_jobs_30d = sync_jobs_30d.where.not(processing_time: nil)
      total_processing_time_30d = processing_jobs_30d.sum(:processing_time).to_f
      waiting_jobs_30d = sync_jobs_30d.where.not(waiting_time: nil)
      first_chunk_processing_jobs_30d = processing_jobs_30d
                                      .where(payload_chunk_index: 0)
                                      .where("COALESCE(payload_chunks, 1) > 1")

      request_rollups_30d = request_rollup_scope(sync_jobs_30d)
      sync_requests_30d = request_rollups_30d.count
      chunked_requests_scope = request_rollups_30d.where("total_chunks > 1")
      chunked_requests_count = chunked_requests_scope.count
      chunked_sync_jobs_30d = chunked_requests_scope.sum(:total_chunks).to_i
      terminal_requests_scope = request_rollups_30d.where("failed_dead_chunks > 0 OR finished_chunks = total_chunks")
      successful_requests_scope = request_rollups_30d.where("failed_dead_chunks = 0 AND finished_chunks = total_chunks")
      failed_requests_scope = request_rollups_30d.where("failed_dead_chunks > 0")
      sync_failed_requests_30d = failed_requests_scope.count
      sync_failed_requests_prev_30d = request_rollup_scope(sync_jobs_prev_30d).where("failed_dead_chunks > 0").count
      request_processing_scope = terminal_requests_scope.where("total_processing_time IS NOT NULL")
      sync_request_processing_sample_size = request_processing_scope.count
      request_waiting_scope = request_rollups_30d.where("first_chunk_waiting_time IS NOT NULL")
      sync_avg_request_total_processing_time = request_processing_scope.average(:total_processing_time)&.to_f&.round(2)
      slow_requests_over_900s_30d = request_processing_scope.where("total_processing_time > 900").count

      if SyncJob.columns_hash.key?("games_count")
        sync_games_30d = sync_jobs_30d.where.not(games_count: nil).sum(:games_count).to_i
        sync_games_prev_30d = sync_jobs_prev_30d.where.not(games_count: nil).sum(:games_count).to_i
        sync_avg_games_per_job = sync_jobs_30d.where.not(games_count: nil).average(:games_count)&.to_f&.round(2)
        sync_avg_games_per_request = average_for_denominator(sync_games_30d, sync_requests_30d)
        sync_avg_processing_time_per_1000_games = processing_jobs_30d.where(games_count: 1000).average(:processing_time)&.to_f&.round(2)
      else
        sync_games_30d = 0
        sync_games_prev_30d = 0
        sync_avg_games_per_job = nil
        sync_avg_games_per_request = nil
        sync_avg_processing_time_per_1000_games = nil
      end

      sync_active_users_30d = sync_jobs_30d.select(:user_id).distinct.count

      {
        sync_jobs_30d:,
        sync_events_30d: sync_status_counts_30d.values.sum,
        sync_events_prev_30d: sync_jobs_prev_30d.group(:status).count.values.sum,
        sync_active_users_30d:,
        sync_finished_30d:,
        sync_failed_30d:,
        sync_dead_30d:,
        sync_running_30d:,
        sync_avg_processing_time: processing_jobs_30d.average(:processing_time)&.round(2),
        sync_avg_processing_time_per_request: average_for_denominator(total_processing_time_30d, sync_requests_30d),
        sync_avg_request_total_processing_time:,
        sync_processing_p50: percentile_cont(processing_jobs_30d, :processing_time, 0.50),
        sync_processing_p95: percentile_cont(processing_jobs_30d, :processing_time, 0.95),
        sync_request_processing_p50: percentile_cont(request_processing_scope, :total_processing_time, 0.50),
        sync_request_processing_p95: percentile_cont(request_processing_scope, :total_processing_time, 0.95),
        sync_request_processing_sample_size:,
        sync_processing_p50_first_chunk: percentile_cont(first_chunk_processing_jobs_30d, :processing_time, 0.50),
        sync_processing_p95_first_chunk: percentile_cont(first_chunk_processing_jobs_30d, :processing_time, 0.95),
        sync_waiting_p50: percentile_cont(waiting_jobs_30d, :waiting_time, 0.50),
        sync_waiting_p95: percentile_cont(waiting_jobs_30d, :waiting_time, 0.95),
        sync_request_waiting_p50: percentile_cont(request_waiting_scope, :first_chunk_waiting_time, 0.50),
        sync_request_waiting_p95: percentile_cont(request_waiting_scope, :first_chunk_waiting_time, 0.95),
        sync_success_rate: sync_success_rate(sync_finished_30d, sync_failed_30d, sync_dead_30d),
        sync_request_success_rate: sync_success_rate(successful_requests_scope.count, sync_failed_requests_30d, 0),
        sync_failed_chunks_30d:,
        sync_failed_requests_30d:,
        sync_failed_requests_prev_30d:,
        chunked_sync_jobs_30d:,
        chunked_sync_requests_30d: chunked_requests_count,
        sync_requests_30d:,
        avg_chunks_per_request_30d: chunked_requests_scope.average(:total_chunks)&.to_f&.round(2),
        p95_chunks_per_request_30d: percentile_cont(request_rollups_30d, :total_chunks, 0.95),
        stddev_chunks_per_request_30d: request_rollups_30d.pick(Arel.sql("STDDEV_POP(total_chunks)"))&.to_f&.round(2),
        max_chunks_per_request_30d: request_rollups_30d.maximum(:total_chunks)&.to_i,
        sync_payload_bytes_30d:,
        sync_payload_bytes_prev_30d:,
        sync_avg_payload_size_bytes:,
        sync_avg_payload_size_per_request_bytes: request_rollups_30d.average(:total_payload_size_bytes)&.to_f&.round,
        sync_games_30d:,
        sync_games_prev_30d:,
        sync_avg_games_per_job:,
        sync_avg_games_per_request:,
        sync_avg_processing_time_per_1000_games:,
        slow_requests_over_900s_30d:,
        latest_sync_event_at: SyncJob.maximum(:created_at),
        sync_requests_per_active_user_30d: average_for_denominator(sync_requests_30d, sync_active_users_30d)
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def sync_success_rate(sync_finished_30d, sync_failed_30d, sync_dead_30d)
      sync_terminal_count = sync_finished_30d + sync_failed_30d + sync_dead_30d
      return "N/A" if sync_terminal_count.zero?

      "#{((sync_finished_30d.to_f / sync_terminal_count) * 100).round(1)}%"
    end

    def average_for_denominator(total, denominator)
      return nil if denominator.to_f <= 0

      (total.to_f / denominator).round(2)
    end

    def percentile_cont(scope, column_name, percentile)
      sql = "PERCENTILE_CONT(#{percentile}) WITHIN GROUP (ORDER BY #{column_name})"
      scope.pick(Arel.sql(sql))&.to_f&.round(2)
    end

    def request_rollup_scope(sync_jobs_scope)
      request_key = request_key_sql("sync_jobs")
      total_games_sql = SyncJob.columns_hash.key?("games_count") ? "SUM(COALESCE(sync_jobs.games_count, 0))" : "0"
      subquery = sync_jobs_scope
                 .select(
                   Arel.sql("#{request_key} AS request_key"),
                   Arel.sql("MAX(COALESCE(sync_jobs.payload_chunks, 1)) AS total_chunks"),
                   Arel.sql("SUM(COALESCE(sync_jobs.processing_time, 0)) AS total_processing_time"),
                   Arel.sql("SUM(COALESCE(sync_jobs.payload_size_bytes, 0)) AS total_payload_size_bytes"),
                   Arel.sql("#{total_games_sql} AS total_games_count"),
                   Arel.sql("SUM(CASE WHEN sync_jobs.status = 'finished' THEN 1 ELSE 0 END) AS finished_chunks"),
                   Arel.sql("SUM(CASE WHEN sync_jobs.status IN ('failed', 'dead') THEN 1 ELSE 0 END) AS failed_dead_chunks"),
                   Arel.sql("MAX(CASE WHEN sync_jobs.payload_chunk_index = 0 THEN sync_jobs.waiting_time END) AS first_chunk_waiting_time")
                 )
                 .group(Arel.sql(request_key))

      SyncJob.unscoped.from("(#{subquery.to_sql}) request_rollups")
    end

    def request_key_sql(table_alias)
      if SyncJob.columns_hash.key?("sync_batch_id")
        "COALESCE(#{table_alias}.sync_batch_id::text, #{table_alias}.id::text)"
      else
        <<~SQL.squish
          CASE
            WHEN COALESCE(#{table_alias}.payload_chunks, 1) > 1 THEN
              CONCAT(
                #{table_alias}.user_id::text,
                '|',
                REGEXP_REPLACE(#{table_alias}.name, ' \\(chunk [0-9]+/[0-9]+\\)$', ''),
                '|',
                DATE_TRUNC('second', #{table_alias}.created_at)::text,
                '|',
                COALESCE(#{table_alias}.payload_chunks, 1)::text
              )
            ELSE #{table_alias}.id::text
          END
        SQL
      end
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
