defmodule Fester.ChainSyncMetrics do
  use GenServer

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
        [:fester, :chain_sync, :catching_up_finished]
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
        {:handle_telemetry_event, [:fester, :chain_sync, :catching_up_started],
         %{timestamp: timestamp}, _metadata},
        state
      ) do
    {:noreply, %{state | start_time: timestamp}}
  end

  def handle_cast(
        {:handle_telemetry_event, [:fester, :chain_sync, :catching_up_finished],
         %{timestamp: timestamp}, _metadata},
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
end
