defmodule Fester.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FesterWeb.Telemetry,
      Fester.Repo,
      {DNSCluster, query: Application.get_env(:fester, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Fester.PubSub},
      {Finch, name: Fester.Finch},
      # Fester.Telemetry.State,
      # Fester.Indexer.Supervisor,
      {Fester.ChainSync, url: System.fetch_env!("OGMIOS_URL")},
      Fester.ChainSyncMetrics,
      FesterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fester.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # Setup telemetry after supervisor starts
    Fester.Telemetry.setup()

    {:ok, sup}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FesterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
