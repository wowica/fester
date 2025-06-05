defmodule Fester.Indexer.Supervisor do
  use Supervisor

  require Logger

  alias Fester.Indexer.Worker

  @addresses [
    "addr_test1qq6rwtv704nmvl0t2lz2f78unjqnw7tw2dhxwmzmtqt3379m3fvnzu46a9vg27umr964njpykthk7ecxz6dvy95462rs7quuny"
  ]

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = Enum.map(addresses(), &{Worker, address: &1})

    Supervisor.init(children, strategy: :one_for_one)
  end

  def addresses, do: @addresses
end
