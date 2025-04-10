defmodule FesterAPI.ChainSync do
  use Xogmios, :chain_sync

  def start_link(opts) do
    initial_state = [sync_from: :babbage]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_block(block, state) do
    :telemetry.execute(
      [:fester_api, :chain_sync, :block_processed],
      %{
        timestamp: System.system_time(:millisecond),
        block_height: block["height"]
      }
    )

    FesterAPI.Indexer.add_to_index(block)

    {:ok, :next_block, state}
  end
end
