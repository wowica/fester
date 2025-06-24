defmodule Fester.Metrics.Indexer do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_tx_avg_duration do
    GenServer.call(__MODULE__, :get_tx_avg_duration)
  end

  def init(_) do
    :telemetry.attach_many(
      "indexer-metrics-handler",
      [
        [:fester, :db_indexer, :tx_start],
        [:fester, :db_indexer, :tx_end]
      ],
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    {:ok,
     %{
       tx_start_time: nil,
       tx_count: 0,
       tx_total_duration: 0
     }}
  end

  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:handle_telemetry_event, event_name, measurements, metadata})
  end

  def handle_call(
        :get_tx_avg_duration,
        _from,
        %{tx_total_duration: tx_total_duration, tx_count: tx_count} = state
      ) do
    {:reply, tx_total_duration / tx_count, state}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :db_indexer, :tx_start],
          %{timestamp: tx_start_time},
          _metadata
        },
        state
      ) do
    {:noreply, %{state | tx_start_time: tx_start_time}}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :db_indexer, :tx_end],
          %{timestamp: tx_end_time},
          _metadata
        },
        state
      ) do
    tx_total_duration = tx_end_time - state.tx_start_time + state.tx_total_duration

    print_metrics(tx_total_duration, state.tx_count + 1)

    {:noreply, %{state | tx_total_duration: tx_total_duration, tx_count: state.tx_count + 1}}
  end

  defp print_metrics(tx_total_duration, tx_count) do
    IO.puts(
      IO.ANSI.format([
        :green,
        "Indexer Tx Processing Time: ",
        :yellow,
        :io_lib.format("~.2f", [tx_total_duration / tx_count]),
        :reset,
        " ms (avg)"
      ])
    )
  end
end
