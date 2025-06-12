defmodule FesterWeb.AssetsController do
  use FesterWeb, :controller

  alias Fester.Indexer

  def index(conn, %{"address" => address}) do
    assets = Indexer.list_assets_by_address(address)
    json(conn, assets)
  end
end
