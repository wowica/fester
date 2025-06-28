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
        [:fester, :db_indexer, :tx_end],
        [:fester, :db_indexer, :tx_inputs_start],
        [:fester, :db_indexer, :tx_inputs_end],
        [:fester, :db_indexer, :tx_input_start],
        [:fester, :db_indexer, :tx_input_end]
      ],
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    {:ok,
     %{
       tx_start_time: nil,
       tx_inputs_start_time: nil,
       tx_input_start_time: nil,
       tx_count: 0,
       acc_tx_duration: 0
     }}
  end

  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:handle_telemetry_event, event_name, measurements, metadata})
  end

  def handle_call(
        :get_tx_avg_duration,
        _from,
        %{acc_tx_duration: acc_tx_duration, tx_count: tx_count} = state
      ) do
    {:reply, acc_tx_duration / tx_count, state}
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
          [:fester, :db_indexer, :tx_inputs_start],
          %{timestamp: timestamp},
          _metadata
        },
        state
      ) do
    {:noreply, %{state | tx_inputs_start_time: timestamp}}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :db_indexer, :tx_inputs_end],
          %{timestamp: timestamp},
          _metadata
        },
        state
      ) do
    IO.puts("Tx Inputs duration: #{timestamp - state.tx_inputs_start_time}")
    {:noreply, %{state | tx_inputs_start_time: nil}}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :db_indexer, :tx_input_start],
          %{timestamp: timestamp},
          _metadata
        },
        state
      ) do
    {:noreply, %{state | tx_input_start_time: timestamp}}
  end

  def handle_cast(
        {
          :handle_telemetry_event,
          [:fester, :db_indexer, :tx_input_end],
          %{timestamp: timestamp},
          _metadata
        },
        state
      ) do
    IO.puts("Tx Single Input duration: #{timestamp - state.tx_input_start_time} ms")
    {:noreply, %{state | tx_input_start_time: nil}}
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
    acc_tx_duration = state.acc_tx_duration + tx_end_time - state.tx_start_time

    print_metrics(acc_tx_duration, state.tx_count + 1)

    {:noreply, %{state | acc_tx_duration: acc_tx_duration, tx_count: state.tx_count + 1}}
  end

  defp print_metrics(acc_tx_duration, tx_count) do
    IO.puts(
      IO.ANSI.format([
        :green,
        "Indexer Tx Processing Time: ",
        :yellow,
        :io_lib.format("~.2f", [acc_tx_duration / tx_count]),
        :reset,
        " ms (avg)"
      ])
    )
  end
end
