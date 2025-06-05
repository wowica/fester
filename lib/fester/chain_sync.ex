defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  alias Fester.Indexer

  def start_link(opts) do
    initial_state = [sync_from: :conway]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot
        } = _block,
        state
      ) do
    IO.puts("Handling new block")
    Indexer.add_to_index(slot, transactions)

    {:ok, :next_block, state}
  end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, state) do
    IO.puts("Handling rollback to slot #{slot}")
    Indexer.rollback_to_slot(slot)

    {:ok, :next_block, state}
  end
end
