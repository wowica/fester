defmodule Fester.Metrics.ChainSync do
  use GenServer

  alias Fester.Metrics.IndexState

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_duration do
    GenServer.call(__MODULE__, :get_duration)
  end

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

    {:ok, %{start_time: nil, duration: nil}}
  end

  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:handle_telemetry_event, event_name, measurements, metadata})
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :chain_sync, :block_processed],
          %{timestamp: now, block_height: height},
          _metadata
        },
        state
      ) do
    # Get current state
    index_state = IndexState.get_state()

    # Calculate throughput
    {new_index_state, instant_throughput, avg_throughput} = calculate_throughput(index_state, now)

    # Update state
    IndexState.update_state(new_index_state)

    # Print metrics
    print_metrics(instant_throughput, avg_throughput, height)

    {:noreply, state}
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
    {:noreply, %{state | start_time: timestamp}}
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
      %{start_time: start_time} when not is_nil(start_time) ->
        duration = timestamp - start_time
        {:noreply, %{state | start_time: nil, duration: duration}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_call(:get_duration, _from, %{duration: duration} = state) do
    {:reply, duration, state}
  end

  defp calculate_throughput(state, now) do
    cond do
      is_nil(state.start_timestamp) ->
        # First block
        new_state = %{state | start_timestamp: now, last_timestamp: now, block_count: 1}
        {new_state, 0.0, 0.0}

      true ->
        # Subsequent blocks
        time_diff = now - state.last_timestamp
        total_time = now - state.start_timestamp

        # Handle edge cases where time_diff or total_time is zero or negative
        instant_throughput = if time_diff > 0, do: 1000 / time_diff, else: 0.0
        avg_throughput = if total_time > 0, do: state.block_count * 1000 / total_time, else: 0.0

        new_state = %{state | last_timestamp: now, block_count: state.block_count + 1}
        {new_state, instant_throughput, avg_throughput}
    end
  end

  defp print_metrics(_instant_throughput, avg_throughput, height) do
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
