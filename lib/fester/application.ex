defmodule Fester.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FesterWeb.Telemetry,
      # TODO: Extract these Metrics into a Supervisor
      Fester.Metrics.ChainSync,
      Fester.Metrics.Indexer,
      Fester.Metrics.Aggregator,
      Fester.Repo,
      {DNSCluster, query: Application.get_env(:fester, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Fester.PubSub},
      {Finch, name: Fester.Finch},
      {Fester.ChainSync, url: System.fetch_env!("OGMIOS_URL")},
      FesterWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Fester.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

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
