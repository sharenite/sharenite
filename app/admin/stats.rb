# frozen_string_literal: true

ActiveAdmin.register_page "Stats" do
  menu priority: 2, label: "Stats"

  content title: "Stats" do
    group_by_options = %w[day week month].freeze
    from = begin
      Date.parse(params[:from].to_s)
    rescue ArgumentError, TypeError
      30.days.ago.to_date
    end
    to = begin
      Date.parse(params[:to].to_s)
    rescue ArgumentError, TypeError
      Date.current
    end
    from, to = [from, to].minmax
    default_group = (to - from).to_i > 180 ? "week" : "day"
    grouping = params[:group_by].presence || default_group
    metrics = Admin::StatsMetrics.call(from:, to:, grouping:)
    no_range_activity = %i[users games sync_events sync_requests sync_games sync_payload_bytes]
                        .all? { |key| metrics[:summary][key][:current].to_f.zero? }
    number = ->(value) { helpers.number_with_delimiter(value) }
    human_size = ->(bytes) { helpers.number_to_human_size(bytes, precision: 2) }
    percent = ->(value) { format("%.1f%%", value.to_f) }
    chart_value = lambda do |value|
      numeric = value.to_f
      if (numeric % 1).zero?
        helpers.number_with_delimiter(numeric.to_i)
      else
        helpers.number_with_precision(numeric, precision: 2, strip_insignificant_zeros: true)
      end
    end

    trend_class = lambda do |change_text|
      return "is-neutral" unless change_text.start_with?("+", "-")
      return "is-up" if change_text.start_with?("+")

      "is-down"
    end

    summary_card = lambda do |label, values, formatter = number|
      div class: "admin-kpi-card" do
        div label, class: "admin-kpi-label"
        div formatter.call(values[:current]), class: "admin-kpi-value"
        div "Prev range: #{formatter.call(values[:previous])}", class: "admin-kpi-meta"
        span values[:change], class: "admin-kpi-trend #{trend_class.call(values[:change])}"
      end
    end

    render_chart = lambda do |title, points, chart_type: :count|
      percent_chart = chart_type == :percent
      label_step =
        if points.size > 120
          10
        elsif points.size > 80
          8
        elsif points.size > 50
          6
        elsif points.size > 30
          4
        elsif points.size > 16
          2
        else
          1
        end
      panel title do
        max_value = if percent_chart
                      100.0
                    else
                      [points.pluck(:value).max.to_f, 1.0].max
                    end
        y_axis_top = max_value
        y_axis_mid = (max_value / 2.0)
        axis_label = lambda do |value|
          rendered = chart_value.call(value)
          percent_chart ? "#{rendered}%" : rendered
        end

        div class: "admin-mini-chart-wrap" do
          div class: "admin-mini-chart-axis" do
            span axis_label.call(y_axis_top), class: "admin-mini-chart-axis-label"
            span axis_label.call(y_axis_mid), class: "admin-mini-chart-axis-label"
            span axis_label.call(0), class: "admin-mini-chart-axis-label"
          end

          div class: "admin-mini-chart" do
            points.each_with_index do |point, index|
              point_value = point[:value]
              formatted_value = chart_value.call(point_value)
              tooltip_value = percent_chart ? "#{formatted_value}%" : formatted_value
              height = ((point_value.to_f / max_value) * 100).round
              show_label = (index % label_step).zero? || index == points.size - 1
              div class: "admin-mini-chart-col" do
                div "",
                    class: "admin-mini-chart-bar",
                    style: "height: #{[height, 2].max}px",
                    title: "#{point[:label]}: #{tooltip_value}"
                span point[:label], class: "admin-mini-chart-label #{show_label ? '' : 'is-hidden'}"
              end
            end
          end
        end
      end
    end

    render_stacked_chart = lambda do |title, points|
      label_step =
        if points.size > 120
          10
        elsif points.size > 80
          8
        elsif points.size > 50
          6
        elsif points.size > 30
          4
        elsif points.size > 16
          2
        else
          1
        end

      panel title do
        max_value = [points.pluck(:value).max.to_f, 1.0].max
        y_axis_top = max_value
        y_axis_mid = (max_value / 2.0)

        div class: "admin-mini-chart-legend" do
          span "Finished", class: "legend-item is-finished"
          span "Failed", class: "legend-item is-failed"
          span "Dead", class: "legend-item is-dead"
        end

        div class: "admin-mini-chart-wrap" do
          div class: "admin-mini-chart-axis" do
            span chart_value.call(y_axis_top), class: "admin-mini-chart-axis-label"
            span chart_value.call(y_axis_mid), class: "admin-mini-chart-axis-label"
            span chart_value.call(0), class: "admin-mini-chart-axis-label"
          end

          div class: "admin-mini-chart" do
            points.each_with_index do |point, index|
              finished = point[:finished].to_i
              failed = point[:failed].to_i
              dead = point[:dead].to_i
              total = point[:value].to_i
              total_height = ((total.to_f / max_value) * 100).round
              show_label = (index % label_step).zero? || index == points.size - 1
              title_text = "#{point[:label]}: finished #{finished}, failed #{failed}, dead #{dead}"

              div class: "admin-mini-chart-col" do
                div class: "admin-mini-chart-bar-stack", style: "height: #{[total_height, 2].max}px", title: title_text do
                  if total.positive?
                    finished_pct = (finished.to_f / total * 100).round(2)
                    failed_pct = (failed.to_f / total * 100).round(2)
                    dead_pct = (dead.to_f / total * 100).round(2)
                    div "", class: "admin-mini-chart-segment is-finished", style: "height: #{finished_pct}%"
                    div "", class: "admin-mini-chart-segment is-failed", style: "height: #{failed_pct}%"
                    div "", class: "admin-mini-chart-segment is-dead", style: "height: #{dead_pct}%"
                  end
                end
                span point[:label], class: "admin-mini-chart-label #{show_label ? '' : 'is-hidden'}"
              end
            end
          end
        end
      end
    end

    div class: "admin-dashboard" do
      div class: "admin-stats-filters" do
        form action: admin_stats_path, method: :get do
          div class: "admin-stats-filter-grid" do
            div do
              label "From", for: "from"
              input type: "date", id: "from", name: "from", value: from.to_s
            end
            div do
              label "To", for: "to"
              input type: "date", id: "to", name: "to", value: to.to_s
            end
            div do
              label "Group by", for: "group_by"
              select id: "group_by", name: "group_by" do
                group_by_options.each do |group_value|
                  option group_value.titleize, value: group_value, selected: (metrics[:grouping] == group_value)
                end
              end
            end
            div class: "admin-stats-filter-actions" do
              button "Apply", type: "submit", class: "button"
              text_node(link_to("Clear", admin_stats_path, class: "admin-stats-clear-link"))
            end
          end
        end
      end

      div class: "admin-dashboard-kpis" do
        summary_card.call("New users", metrics[:summary][:users])
        summary_card.call("New games", metrics[:summary][:games])
        summary_card.call("Sync events", metrics[:summary][:sync_events])
        summary_card.call("Sync requests", metrics[:summary][:sync_requests])
        summary_card.call("Synced games", metrics[:summary][:sync_games])
        summary_card.call("Sync payload", metrics[:summary][:sync_payload_bytes], human_size)
        summary_card.call("Avg games/request", metrics[:summary][:sync_avg_games_per_request], chart_value)
        summary_card.call("Avg proc/request (s)", metrics[:summary][:sync_avg_processing_per_request_seconds], chart_value)
        summary_card.call("User-to-sync <=7d", metrics[:summary][:user_sync_conversion_7d], percent)
      end

      div class: "admin-stats-charts" do
        if no_range_activity
          div class: "admin-stats-empty-note" do
            strong "No activity in selected range."
            text_node " Try widening the date range or changing grouping."
          end
        end

        render_chart.call("Users Created", metrics[:series][:users])
        render_chart.call("Games Added", metrics[:series][:games])
        render_chart.call("Sync Active Users", metrics[:series][:sync_active_users])
        render_chart.call("Sync Requests", metrics[:series][:sync_requests])
        render_stacked_chart.call("Sync Status (finished/failed/dead)", metrics[:series][:sync_status_stack])
        render_chart.call("Synced Games", metrics[:series][:sync_games])
        render_chart.call("Avg Games/Request", metrics[:series][:sync_avg_games_per_request])
        render_chart.call("Avg Processing/Request (s)", metrics[:series][:sync_avg_processing_per_request_seconds])
        render_chart.call("User-to-sync conversion <=7d (%)", metrics[:series][:user_sync_conversion_7d], chart_type: :percent)
      end
    end
  end
end
