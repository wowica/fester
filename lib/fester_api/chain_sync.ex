defmodule FesterAPI.ChainSync do
  use Xogmios, :chain_sync

  def start_link(opts) do
    initial_state = [sync_from: :babbage]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_block(block, state) do
    IO.puts("handle_block #{block["height"]}")

    FesterAPI.Indexer.add_to_index(block)

    {:ok, :next_block, state}
  end
end
