defmodule Fester.Indexer.Supervisor do
  use Supervisor

  require Logger

  alias Fester.Indexer.Worker

  @addresses [
    "addr_test1qz7dlq960jgsc0td7pfy8406xyz6f9rrmtm3473c03nj9996vp3ydcd35um7n5xw60t7lmhjj7vgskmurlln0kawd6gqpuqr76"
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
