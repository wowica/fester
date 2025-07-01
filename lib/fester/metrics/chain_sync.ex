defmodule Fester.Metrics.ChainSync do
  use GenServer

  ## Public API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_duration do
    GenServer.call(__MODULE__, :get_duration)
  end

  ## Callbacks

  def init(_) do
    :telemetry.attach_many(
      "chain-sync-metrics-handler",
      [
        [:fester, :chain_sync, :catching_up_started],
        [:fester, :chain_sync, :catching_up_finished],
        [:fester, :chain_sync, :block_processed]
      ],
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    {:ok,
     %{
       sync_start_time: nil,
       last_timestamp: nil,
       start_block_height: nil,
       current_block_height: 0,
       duration: 0
     }}
  end

  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:handle_telemetry_event, event_name, measurements, metadata})
  end

  # Tracks the first block processed and stores the start block height.
  # This value is used to calculated the average throughput.
  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :chain_sync, :block_processed],
          %{timestamp: now, block_height: current_height},
          _metadata
        },
        %{
          sync_start_time: start_timestamp,
          start_block_height: nil
        } = state
      ) do
    avg_throughput = calculate_throughput(start_timestamp, current_height, now, current_height)
    print_metrics(avg_throughput, current_height)

    {:noreply,
     %{
       state
       | last_timestamp: now,
         start_block_height: current_height,
         current_block_height: current_height
     }}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :chain_sync, :block_processed],
          %{timestamp: now, block_height: current_height},
          _metadata
        },
        %{
          sync_start_time: start_timestamp,
          start_block_height: start_block_height
        } = state
      ) do
    avg_throughput =
      calculate_throughput(start_timestamp, start_block_height, now, current_height)

    print_metrics(avg_throughput, current_height)

    {:noreply, %{state | last_timestamp: now, current_block_height: current_height}}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :chain_sync, :catching_up_started],
          %{timestamp: timestamp},
          _metadata
        },
        state
      ) do
    {:noreply, %{state | sync_start_time: timestamp}}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :chain_sync, :catching_up_finished],
          %{timestamp: timestamp},
          _metadata
        },
        state
      ) do
    case state do
      %{sync_start_time: start_time} when not is_nil(start_time) ->
        duration = timestamp - start_time
        {:noreply, %{state | sync_start_time: nil, duration: duration}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_call(:get_duration, _from, %{duration: duration} = state) do
    {:reply, duration, state}
  end

  defp calculate_throughput(start_timestamp, start_block_height, now, current_height) do
    cond do
      is_nil(start_timestamp) ->
        # First block
        0.0

      true ->
        # Subsequent blocks
        total_time = now - start_timestamp
        total_blocks_processed = current_height - start_block_height + 1

        avg_throughput =
          if total_time > 0, do: total_blocks_processed * 1000 / total_time, else: 0.0

        avg_throughput
    end
  end

  defp print_metrics(avg_throughput, height) do
    IO.puts(
      IO.ANSI.format([
        :green,
        "Chain Sync Throughput: ",
        :yellow,
        :io_lib.format("~.2f", [avg_throughput]),
        :reset,
        " blocks/second (avg) | height: #{height}"
      ])
    )
  end
end
