defmodule FesterWeb.UtxosController do
  use FesterWeb, :controller

  alias Fester.Indexer

  def index(conn, %{"address" => address}) do
    utxos = Indexer.list_utxos_by_address(address)

    json(conn, utxos)
  end
end
