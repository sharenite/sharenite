# frozen_string_literal: true

module Admin
  # Provides grouped time-series and period comparisons for admin stats page.
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

    def call
      {
        from:,
        to:,
        grouping:,
        summary:,
        series: {
          users: grouped_counts(User, :created_at),
          games: grouped_counts(Game, :created_at),
          sync_events: grouped_counts(SyncJob, :created_at)
        }
      }
    end

    private

    attr_reader :from, :to, :grouping

    def summary
      {
        users: period_comparison(User, :created_at),
        games: period_comparison(Game, :created_at),
        sync_events: period_comparison(SyncJob, :created_at)
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
  end
end
