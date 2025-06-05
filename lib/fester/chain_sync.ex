defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  alias Fester.Indexer

  def start_link(opts) do
    initial_state = [sync_from: :conway]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_block(%{"transactions" => transactions} = _block, state) do
    IO.puts("Hanlding new block")
    Indexer.add_to_index(transactions)

    {:ok, :next_block, state}
  end
end
