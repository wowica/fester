defmodule FesterAPI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FesterAPIWeb.Telemetry,
      FesterAPI.Repo,
      {DNSCluster, query: Application.get_env(:fester_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FesterAPI.PubSub},
      {Finch, name: FesterAPI.Finch},
      FesterAPI.Telemetry.State,
      {FesterAPI.Indexer, []},
      {FesterAPI.ChainSync, url: System.fetch_env!("OGMIOS_URL")},
      FesterAPIWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FesterAPI.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # Setup telemetry after supervisor starts
    FesterAPI.Telemetry.setup()

    {:ok, sup}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FesterAPIWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
