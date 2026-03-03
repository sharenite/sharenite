# frozen_string_literal: true

module Admin
  # Provides grouped time-series and period comparisons for admin stats page.
  # rubocop:disable Metrics/ClassLength
  class StatsMetrics
    GROUPS = %w[day week month].freeze

    class << self
      def call(from:, to:, grouping:)
        new(from:, to:, grouping:).call
      end
    end

    def initialize(from:, to:, grouping:)
      @from = from.in_time_zone.beginning_of_day
      @to = to.in_time_zone.end_of_day
      @grouping = GROUPS.include?(grouping.to_s) ? grouping.to_s : "day"
    end

    # rubocop:disable Metrics/MethodLength
    def call
      {
        from:,
        to:,
        grouping:,
        summary:,
        series: {
          users: grouped_counts(User, :created_at),
          games: grouped_counts(Game, :created_at),
          sync_events: grouped_counts(SyncJob, :created_at),
          sync_failed_events: grouped_counts(SyncJob.where(status: %w[failed dead]), :created_at),
          sync_finished_events: grouped_counts(SyncJob.where(status: "finished"), :created_at),
          sync_active_users: grouped_distinct_counts(SyncJob, :created_at, :user_id),
          user_sync_conversion_7d: grouped_user_sync_conversion_rate(days: 7),
          sync_games: sync_games_series,
          sync_payload_mb: grouped_sums(SyncJob, :created_at, :payload_size_bytes, scale: 1.megabyte.to_f)
        }
      }
    end
    # rubocop:enable Metrics/MethodLength

    private

    attr_reader :from, :to, :grouping

    def summary
      {
        users: period_comparison(User, :created_at),
        games: period_comparison(Game, :created_at),
        sync_events: period_comparison(SyncJob, :created_at),
        sync_games: sync_games_summary,
        sync_payload_bytes: period_sum_comparison(SyncJob, :created_at, :payload_size_bytes),
        user_sync_conversion_7d: user_sync_conversion_summary(days: 7)
      }
    end

    def period_comparison(model, column)
      current = model.where(column => from..to).count
      previous = model.where(column => previous_range).count
      {
        current:,
        previous:,
        change: percent_change(current, previous)
      }
    end

    def previous_range
      duration = to - from
      previous_to = from - 1.second
      previous_from = previous_to - duration
      previous_from..previous_to
    end

    def grouped_counts(model, column)
      trunc = "date_trunc('#{grouping}', #{column})"
      data = model.where(column => from..to)
                  .group(Arel.sql(trunc))
                  .order(Arel.sql(trunc))
                  .count

      fill_missing_points(data).map do |time, value|
        { time:, label: time.strftime(label_format), value: }
      end
    end

    def grouped_distinct_counts(model, column, distinct_column)
      trunc = "date_trunc('#{grouping}', #{column})"
      grouped = model.where(column => from..to)
                     .group(Arel.sql(trunc))
                     .order(Arel.sql(trunc))
                     .pluck(
                       Arel.sql(trunc),
                       Arel.sql("COUNT(DISTINCT #{distinct_column})")
                     )

      data = grouped.to_h
      fill_missing_points(data).map do |time, value|
        { time:, label: time.strftime(label_format), value: }
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def grouped_user_sync_conversion_rate(days:)
      trunc = "date_trunc('#{grouping}', users.created_at)"
      grouped = User.where(created_at: from..to)
                    .joins(<<~SQL.squish)
                      LEFT JOIN sync_jobs sync_conversion
                        ON sync_conversion.user_id = users.id
                       AND sync_conversion.created_at >= users.created_at
                       AND sync_conversion.created_at <= users.created_at + interval '#{days} days'
                    SQL
                    .group(Arel.sql(trunc))
                    .order(Arel.sql(trunc))
                    .pluck(
                      Arel.sql(trunc),
                      Arel.sql("COUNT(DISTINCT users.id)"),
                      Arel.sql("COUNT(DISTINCT CASE WHEN sync_conversion.id IS NOT NULL THEN users.id END)")
                    )

      data = grouped.each_with_object({}) do |(time, total, converted), acc|
        total_count = total.to_i
        converted_count = converted.to_i
        rate = total_count.zero? ? 0.0 : ((converted_count.to_f / total_count) * 100).round(1)
        acc[time] = rate
      end

      fill_missing_points(data).map do |time, value|
        { time:, label: time.strftime(label_format), value: value.to_f.round(1) }
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize
    def grouped_sums(model, column, sum_column, scale: 1.0)
      trunc = "date_trunc('#{grouping}', #{column})"
      data = model.where(column => from..to)
                  .group(Arel.sql(trunc))
                  .order(Arel.sql(trunc))
                  .sum(sum_column)

      fill_missing_points(data).map do |time, value|
        scaled_value = (value.to_f / scale)
        scaled_value = scaled_value.round(2) if (scale - 1.0).abs > Float::EPSILON
        { time:, label: time.strftime(label_format), value: scaled_value }
      end
    end
    # rubocop:enable Metrics/AbcSize

    def fill_missing_points(data)
      step = grouping_step
      points = {}
      cursor = from.beginning_of_day
      while cursor <= to
        key = truncate_time(cursor)
        points[key] ||= data[key] || 0
        cursor += step
      end
      points.sort.to_h
    end

    def truncate_time(time)
      case grouping
      when "week"
        time.beginning_of_week
      when "month"
        time.beginning_of_month
      else
        time.beginning_of_day
      end
    end

    def grouping_step
      case grouping
      when "week" then 1.week
      when "month" then 1.month
      else 1.day
      end
    end

    def label_format
      case grouping
      when "month" then "%Y-%m"
      when "week" then "W%V %Y"
      else "%Y-%m-%d"
      end
    end

    def percent_change(current, previous)
      if previous.zero?
        current.zero? ? "0.0%" : "+100.0%"
      else
        format("%+.1f%%", ((current - previous).to_f / previous * 100))
      end
    end

    def period_sum_comparison(model, column, sum_column)
      current = model.where(column => from..to).sum(sum_column).to_i
      previous = model.where(column => previous_range).sum(sum_column).to_i
      {
        current:,
        previous:,
        change: percent_change(current, previous)
      }
    end

    # rubocop:disable Metrics/AbcSize
    def user_sync_conversion_summary(days:)
      current_users = User.where(created_at: from..to)
      previous_users = User.where(created_at: previous_range)

      current_total = current_users.count
      previous_total = previous_users.count
      current_converted = users_with_sync_within(current_users, days:).count
      previous_converted = users_with_sync_within(previous_users, days:).count

      current_rate = current_total.zero? ? 0.0 : ((current_converted.to_f / current_total) * 100).round(1)
      previous_rate = previous_total.zero? ? 0.0 : ((previous_converted.to_f / previous_total) * 100).round(1)

      {
        current: current_rate,
        previous: previous_rate,
        change: percent_change(current_rate, previous_rate)
      }
    end
    # rubocop:enable Metrics/AbcSize

    def sync_games_summary
      return zero_comparison unless SyncJob.columns_hash.key?("games_count")

      period_sum_comparison(SyncJob, :created_at, :games_count)
    end

    def sync_games_series
      return zero_series unless SyncJob.columns_hash.key?("games_count")

      grouped_sums(SyncJob, :created_at, :games_count)
    end

    def zero_comparison
      { current: 0, previous: 0, change: "0.0%" }
    end

    def zero_series
      fill_missing_points({}).map do |time, _|
        { time:, label: time.strftime(label_format), value: 0 }
      end
    end

    def users_with_sync_within(scope, days:)
      scope.joins(<<~SQL.squish)
        INNER JOIN sync_jobs sync_conversion
          ON sync_conversion.user_id = users.id
         AND sync_conversion.created_at >= users.created_at
         AND sync_conversion.created_at <= users.created_at + interval '#{days} days'
      SQL
           .distinct
    end
  end
  # rubocop:enable Metrics/ClassLength
end
