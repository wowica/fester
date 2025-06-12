defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  # alias Fester.Indexer
  alias Fester.DBIndexer, as: Indexer

  def start_link(opts) do
    initial_state = [
      sync_from: %{
        point: %{
          slot: 158_167_807,
          id: "25578b57db37c035edc4557fc641012e556ec794befab28f95e9a77629f36676"
        }
      }
    ]

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
