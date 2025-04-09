defmodule FesterAPI.Telemetry do
  def setup do
    :telemetry.attach(
      "fester-api-chain-sync-metrics",
      [:fester_api, :chain_sync, :block_processed],
      &handle_block_processed/4,
      nil
    )
  end

  defp handle_block_processed(
         [:fester_api, :chain_sync, :block_processed],
         %{timestamp: now, block_height: height},
         _metadata,
         _config
       ) do
    # Get current state
    state = FesterAPI.Telemetry.State.get_state()

    # Calculate throughput
    {new_state, instant_throughput, avg_throughput} = calculate_throughput(state, now)

    # Update state
    FesterAPI.Telemetry.State.update_state(new_state)

    # Print metrics
    print_metrics(instant_throughput, avg_throughput, height)
  end

  defp calculate_throughput(state, now) do
    cond do
      is_nil(state.start_timestamp) ->
        # First block
        new_state = %{state | start_timestamp: now, last_timestamp: now, block_count: 1}
        {new_state, 0.0, 0.0}

      is_nil(state.last_timestamp) ->
        # Second block
        time_diff = now - state.start_timestamp
        instant_throughput = 1000 / time_diff
        new_state = %{state | last_timestamp: now, block_count: 2}
        {new_state, instant_throughput, instant_throughput}

      true ->
        # Subsequent blocks
        time_diff = now - state.last_timestamp
        instant_throughput = 1000 / time_diff
        total_time = now - state.start_timestamp
        avg_throughput = state.block_count * 1000 / total_time

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
