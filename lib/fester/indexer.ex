defmodule Fester.Indexer do
  alias Fester.Indexer.Worker, as: Worker
  alias Fester.Indexer.Supervisor, as: Supervisor

  def add_to_index(slot, transactions) do
    for address <- Supervisor.addresses() do
      worker = :"#{address}"
      Worker.add_to_index(worker, slot, transactions)
    end
  end

  def list_assets(address) when is_binary(address) do
    worker = :"#{address}"
    Worker.list_assets(worker)
  end

  def list_assets(address) when is_pid(address) do
    Worker.list_assets(address)
  end

  def rollback_to_slot(slot) do
    for address <- Supervisor.addresses() do
      worker = :"#{address}"
      Worker.rollback_to_slot(worker, slot)
    end
  end
end
