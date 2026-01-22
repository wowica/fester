defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  alias Fester.DBIndexer, as: Indexer
  alias Fester.Metrics.ChainSync

  def start_link(opts) do
    initial_state = [
      is_synced?: false,
      sync_from: :conway
      ## To sync from a specific point in the chain, uncomment the line below
      ## and set the slot and block hash
      # sync_from: {slot, block_hash}
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
    IO.puts("Milliseconds to sync: #{ChainSync.get_duration()}")

    Indexer.add_to_index(slot, transactions)

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{
        timestamp: System.system_time(:millisecond),
        block_height: block_height,
        slot: slot,
        tip_slot: slot
      }
    )

    {:ok, :next_block, state}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "current_tip" => %{"slot" => slot},
          "height" => block_height
        } = _block,
        %{is_synced?: false} = state
      ) do
    IO.puts("Caught up to current tip. Adding new block to index")

    Indexer.add_to_index(slot, transactions)

    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_finished],
      %{timestamp: System.system_time(:millisecond)}
    )

    IO.puts("Milliseconds to sync: #{ChainSync.get_duration()}")

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{
        timestamp: System.system_time(:millisecond),
        block_height: block_height,
        slot: slot,
        tip_slot: slot
      }
    )

    {:ok, :next_block, %{state | is_synced?: true}}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "height" => block_height,
          "current_tip" => %{"slot" => current_tip_slot}
        } = _block,
        %{is_synced?: false} = state
      ) do
    IO.puts("Progress: #{slot / current_tip_slot * 100}%")

    Indexer.add_to_index(slot, transactions)

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{
        timestamp: System.system_time(:millisecond),
        block_height: block_height,
        slot: slot,
        tip_slot: current_tip_slot
      }
    )

    {:ok, :next_block, state}
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
