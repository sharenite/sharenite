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
    number = ->(value) { helpers.number_with_delimiter(value) }
    human_size = ->(bytes) { helpers.number_to_human_size(bytes, precision: 2) }

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

    render_chart = lambda do |title, points|
      panel title do
        max_value = [points.pluck(:value).max.to_i, 1].max
        div class: "admin-mini-chart" do
          points.each do |point|
            height = ((point[:value].to_f / max_value) * 100).round
            div class: "admin-mini-chart-col", title: "#{point[:label]}: #{point[:value]}" do
              div "", class: "admin-mini-chart-bar", style: "height: #{[height, 2].max}px"
              span point[:label], class: "admin-mini-chart-label"
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
        summary_card.call("Users (range)", metrics[:summary][:users])
        summary_card.call("Games (range)", metrics[:summary][:games])
        summary_card.call("Sync events (range)", metrics[:summary][:sync_events])
        summary_card.call("Synced games (range)", metrics[:summary][:sync_games])
        summary_card.call("Sync payload (range)", metrics[:summary][:sync_payload_bytes], human_size)
      end

      render_chart.call("Users Created", metrics[:series][:users])
      render_chart.call("Games Added", metrics[:series][:games])
      render_chart.call("Sync Events", metrics[:series][:sync_events])
      render_chart.call("Synced Games", metrics[:series][:sync_games])
      render_chart.call("Sync Payload (MB)", metrics[:series][:sync_payload_mb])
    end
  end
end
