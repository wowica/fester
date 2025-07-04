defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  alias Fester.DBIndexer, as: Indexer

  def start_link(opts) do
    initial_state = [
      is_synced?: false,
      # sync_from: :origin
      ## To sync from a specific point in the chain, uncomment the line below
      ## and set the slot and block hash
      # Last babbage block in preview testnet
      sync_from: {55_814_394, "bdd4baa2c81d0500a695f836332193ea06c2ce364e585057142220fc0782144c"},
      block_counter: 0
    ]

    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_connect(state) do
    # This first call "warms up" the DB connection
    _ = Fester.Repo.get(Fester.Utxo, "123")
    IO.puts("Warmed up DB connection")

    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_started],
      %{timestamp: System.system_time(:millisecond)}
    )

    {:ok, state}
  end

  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "height" => block_height
        } = _block,
        %{is_synced?: true} = state
      ) do
    IO.puts("Fully synced. Adding new block to index.")

    Indexer.add_to_index(slot, transactions)

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{timestamp: System.system_time(:millisecond), block_height: block_height}
    )

    {:ok, :next_block, state}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "height" => block_height
        } = _block,
        %{is_synced?: false, block_counter: 1000} = state
      ) do
    Indexer.add_to_index(slot, transactions)

    IO.puts("Finished syncing 1000 blocks")

    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_finished],
      %{timestamp: System.system_time(:millisecond)}
    )

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{timestamp: System.system_time(:millisecond), block_height: block_height}
    )

    {:ok, state}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "height" => block_height,
          "current_tip" => %{"slot" => current_tip_slot}
        } = _block,
        %{is_synced?: false, block_counter: counter} = state
      ) do
    IO.puts("Progress: #{slot / current_tip_slot * 100}%")

    Indexer.add_to_index(slot, transactions)

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{timestamp: System.system_time(:millisecond), block_height: block_height}
    )

    {:ok, :next_block, %{state | block_counter: counter + 1}}
  end

  # Needed for mainnet, where Ogmios returns neither "transactions"
  # nor "slot" properties for the genesis block.
  @impl true
  def handle_block(
        %{
          "height" => _height
        } = _block,
        %{is_synced?: false} = state
      ) do
    # On mainnet, Ogmios appears to not return the "transactions"
    # key when no transactions are present in a block.
    {:ok, :next_block, state}
  end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, state) do
    IO.puts("Handling rollback to slot #{slot}")

    Indexer.rollback_to_slot(slot)
    {:ok, :next_block, state}
  end
end
