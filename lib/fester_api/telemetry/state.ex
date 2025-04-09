defmodule FesterAPI.Telemetry.State do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{last_timestamp: nil, block_count: 0, start_timestamp: nil} end,
      name: __MODULE__
    )
  end

  def get_state do
    Agent.get(__MODULE__, & &1)
  end

  def update_state(new_state) do
    Agent.update(__MODULE__, fn _ -> new_state end)
  end
end
