defmodule Fester.Telemetry do
  alias Fester.Telemetry.State

  def setup do
    :telemetry.attach(
      "fester-api-chain-sync-metrics",
      [:fester, :chain_sync, :block_processed],
      &__MODULE__.handle_block_processed/4,
      nil
    )
  end

  def handle_block_processed(
        [:fester, :chain_sync, :block_processed],
        %{timestamp: now, block_height: height},
        _metadata,
        _config
      ) do
    # Get current state
    state = State.get_state()

    # Calculate throughput
    {new_state, instant_throughput, avg_throughput} = calculate_throughput(state, now)

    # Update state
    State.update_state(new_state)

    # Print metrics
    print_metrics(instant_throughput, avg_throughput, height)
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

  # defp print_metrics(instant_throughput, avg_throughput, height) do
  #   IO.puts(
  #     IO.ANSI.format([
  #       :green,
  #       "Chain Sync Throughput: ",
  #       :yellow,
  #       :io_lib.format("~.2f", [instant_throughput]),
  #       :reset,
  #       " blocks/second (instant) | ",
  #       :yellow,
  #       :io_lib.format("~.2f", [avg_throughput]),
  #       :reset,
  #       " blocks/second (avg) | height: #{height}"
  #     ])
  #   )
  # end

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
