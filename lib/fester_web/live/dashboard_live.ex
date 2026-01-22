defmodule FesterWeb.DashboardLive do
  @moduledoc """
  Real-time metrics dashboard for Fester.
  """

  use FesterWeb, :live_view

  alias Fester.Metrics.Aggregator

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Aggregator.subscribe()

    metrics = Aggregator.get_metrics()

    {:ok, assign(socket, metrics: metrics)}
  end

  @impl true
  def handle_info({:metrics_update, metrics}, socket) do
    {:noreply, assign(socket, metrics: metrics)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="header">
      <div class="header-title">
        <h1>Fester - Metrics Dashboard</h1>
      </div>
      <div class={["status-badge", status_class(@metrics.is_syncing)]}>
        <span class={["status-dot", status_class(@metrics.is_syncing)]}></span>
        <%= if @metrics.is_syncing, do: "Syncing", else: "Synced" %>
      </div>
    </div>

    <div class="progress-section">
      <div class="progress-header">
        <span class="progress-label">Sync Progress</span>
        <span class={["progress-percentage", progress_color_class(@metrics.sync_percentage)]}>
          <%= Float.round(@metrics.sync_percentage, 1) %>%
        </span>
      </div>
      <div class="progress-bar-container">
        <div
          class={["progress-bar-fill", progress_color_class(@metrics.sync_percentage), if(@metrics.sync_percentage < 100, do: "shimmer", else: "")]}
          style={"width: #{@metrics.sync_percentage}%"}
        >
        </div>
      </div>
      <div class="progress-slots">
        Slot <%= @metrics.current_slot %> of <%= @metrics.tip_slot %>
      </div>
    </div>

    <div class="metrics-grid">
      <div class="metric-card blue">
        <div class="label">Chain Sync Throughput</div>
        <div class="value">
          <%= @metrics.blocks_per_second %>
          <span class="unit">blocks/sec</span>
        </div>
      </div>

      <div class="metric-card green">
        <div class="label">Tx Processing Time</div>
        <div class="value">
          <%= @metrics.tx_avg_duration %>
          <span class="unit">ms avg</span>
        </div>
      </div>

      <div class="metric-card orange">
        <div class="label">Time to Sync</div>
        <div class="value">
          <%= format_sync_duration(@metrics.sync_duration, @metrics.is_syncing) %>
        </div>
      </div>

      <div class="metric-card">
        <div class="label">Service Uptime</div>
        <div class="value">
          <%= format_duration(@metrics.uptime) %>
        </div>
      </div>
    </div>

    <div class="info-panel">
      <div class="info-row">
        <span class="label">Current Block Height</span>
        <span class="value"><%= @metrics.current_block_height %></span>
      </div>
      <div class="info-row">
        <span class="label">Sync Status</span>
        <span class="value"><%= if @metrics.is_syncing, do: "Catching up to tip", else: "At chain tip" %></span>
      </div>
    </div>
    """
  end

  defp status_class(true), do: "syncing"
  defp status_class(false), do: "synced"

  defp format_sync_duration(nil, _), do: "--"
  defp format_sync_duration(duration, true), do: "#{format_duration(duration)}..."
  defp format_sync_duration(duration, false), do: format_duration(duration)

  defp format_duration(ms) when is_nil(ms), do: "--"

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) do
    total_seconds = div(ms, 1000)
    days = div(total_seconds, 86400)
    hours = div(rem(total_seconds, 86400), 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    seconds = rem(total_seconds, 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m #{seconds}s"
      minutes > 0 -> "#{minutes}m #{seconds}s"
      true -> "#{seconds}s"
    end
  end

  defp progress_color_class(percentage) when percentage >= 100, do: "synced"
  defp progress_color_class(_), do: "syncing"
end
