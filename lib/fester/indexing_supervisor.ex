defmodule Fester.IndexingSupervisor do
  use Supervisor

  @addresses [
    "addr_test1qr35ar8m5svfzesp6cz372lnmkq8u4akg4rkj7r59rc7nd65sup28tlrwy25hmhrxarfcegmhsz0glfvqtnhl9x2g9lsgwag4z",
    "addr_test1qpye08rch6z6ll94m0pe405gl34cllw55qdtcnmvym2js9h6u7xkk6lmrrdry2l0perrkmhsakpvvcvcutkupemqf2cqex3txv"
  ]

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children =
      Enum.map(@addresses, fn address ->
        {Fester.Indexer.Worker, address: address}
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def add_to_index(transactions) do
    for address <- @addresses do
      worker = :"#{address}"
      Fester.Indexer.Worker.add_to_index(worker, transactions)
    end
  end
end
