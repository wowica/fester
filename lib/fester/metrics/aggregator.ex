defmodule Fester.Metrics.Aggregator do
  @moduledoc """
  Aggregates telemetry metrics and broadcasts them to subscribed LiveView clients.
  """

  use GenServer

  @pubsub Fester.PubSub
  @topic "metrics"
  @broadcast_interval 1_000

  ## Public API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Returns the current aggregated metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Subscribes the calling process to metrics updates.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  ## Callbacks

  @impl true
  def init(_) do
    :telemetry.attach_many(
      "metrics-aggregator-handler",
      [
        [:fester, :chain_sync, :catching_up_started],
        [:fester, :chain_sync, :catching_up_finished],
        [:fester, :chain_sync, :block_processed],
        [:fester, :db_indexer, :tx_start],
        [:fester, :db_indexer, :tx_end]
      ],
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    schedule_broadcast()

    {:ok,
     %{
       service_started_at: System.monotonic_time(:millisecond),
       sync_start_time: nil,
       sync_end_time: nil,
       sync_start_block: nil,
       current_block_height: 0,
       blocks_per_second: 0.0,
       tx_count: 0,
       tx_total_duration: 0,
       tx_avg_duration: 0.0,
       tx_start_time: nil,
       is_syncing: false,
       current_slot: 0,
       tip_slot: 0,
       sync_percentage: 0.0
     }}
  end

  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:telemetry, event_name, measurements, metadata})
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, build_metrics(state), state}
  end

  @impl true
  def handle_cast(
        {:telemetry, [:fester, :chain_sync, :catching_up_started], %{timestamp: timestamp}, _},
        state
      ) do
    {:noreply,
     %{
       state
       | sync_start_time: timestamp,
         sync_end_time: nil,
         sync_start_block: nil,
         is_syncing: true
     }}
  end

  def handle_cast(
        {:telemetry, [:fester, :chain_sync, :catching_up_finished], %{timestamp: timestamp}, _},
        state
      ) do
    {:noreply, %{state | sync_end_time: timestamp, is_syncing: false}}
  end

  def handle_cast(
        {:telemetry, [:fester, :chain_sync, :block_processed],
         %{timestamp: now, block_height: height} = measurements, _},
        state
      ) do
    sync_start_block = state.sync_start_block || height
    blocks_per_second = calculate_throughput(state.sync_start_time, sync_start_block, now, height)

    # Extract slot data if present
    current_slot = Map.get(measurements, :slot, state.current_slot)
    tip_slot = Map.get(measurements, :tip_slot, state.tip_slot)

    sync_percentage =
      if tip_slot > 0 do
        min(current_slot / tip_slot * 100, 100.0)
      else
        0.0
      end

    {:noreply,
     %{
       state
       | current_block_height: height,
         blocks_per_second: blocks_per_second,
         sync_start_block: sync_start_block,
         current_slot: current_slot,
         tip_slot: tip_slot,
         sync_percentage: sync_percentage
     }}
  end

  def handle_cast(
        {:telemetry, [:fester, :db_indexer, :tx_start], %{timestamp: timestamp}, _},
        state
      ) do
    {:noreply, %{state | tx_start_time: timestamp}}
  end

  def handle_cast(
        {:telemetry, [:fester, :db_indexer, :tx_end], %{timestamp: timestamp}, _},
        %{tx_start_time: tx_start} = state
      )
      when not is_nil(tx_start) do
    duration = timestamp - tx_start
    tx_count = state.tx_count + 1
    tx_total = state.tx_total_duration + duration
    tx_avg = tx_total / tx_count

    {:noreply,
     %{
       state
       | tx_count: tx_count,
         tx_total_duration: tx_total,
         tx_avg_duration: tx_avg,
         tx_start_time: nil
     }}
  end

  def handle_cast({:telemetry, _, _, _}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:broadcast, state) do
    metrics = build_metrics(state)
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:metrics_update, metrics})
    schedule_broadcast()
    {:noreply, state}
  end

  ## Private

  defp schedule_broadcast do
    Process.send_after(self(), :broadcast, @broadcast_interval)
  end

  defp build_metrics(state) do
    %{
      blocks_per_second: Float.round(state.blocks_per_second, 2),
      tx_avg_duration: Float.round(state.tx_avg_duration, 2),
      current_block_height: state.current_block_height,
      is_syncing: state.is_syncing,
      sync_duration: calculate_sync_duration(state),
      uptime: System.monotonic_time(:millisecond) - state.service_started_at,
      current_slot: state.current_slot,
      tip_slot: state.tip_slot,
      sync_percentage: Float.round(state.sync_percentage, 2)
    }
  end

  defp calculate_throughput(nil, _, _, _), do: 0.0

  defp calculate_throughput(start_time, start_block, now, current_height) do
    total_time = now - start_time
    total_blocks = current_height - start_block + 1

    if total_time > 0 do
      total_blocks * 1000 / total_time
    else
      0.0
    end
  end

  defp calculate_sync_duration(%{sync_start_time: nil}), do: nil

  defp calculate_sync_duration(%{sync_start_time: start, sync_end_time: nil}) do
    System.system_time(:millisecond) - start
  end

  defp calculate_sync_duration(%{sync_start_time: start, sync_end_time: finish}) do
    finish - start
  end
end
