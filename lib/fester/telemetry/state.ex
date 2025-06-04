defmodule Fester.Telemetry.State do
  use Agent

  def start_link(_) do
    initial_state = fn ->
      %{start_timestamp: nil, last_timestamp: nil, block_count: 0}
    end

    Agent.start_link(initial_state, name: __MODULE__)
  end

  def get_state do
    Agent.get(__MODULE__, & &1)
  end

  def update_state(new_state) do
    Agent.update(__MODULE__, fn _ -> new_state end)
  end
end
