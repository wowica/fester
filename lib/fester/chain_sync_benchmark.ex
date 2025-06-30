defmodule Fester.ChainSyncBenchmark do
  # This is a copy of Fester.ChainSync but with a different sync_from point and a different blocks_count.
  # It's used to benchmark the performance of the chain sync process.
  use Xogmios, :chain_sync

  alias Fester.DBIndexer, as: Indexer

  def start_link(opts) do
    initial_state = [
      is_synced?: false,
      sync_from: {84_490_987, "c72c90acae60cdcbf4402e39c73ca8c8f6ff6fcac6e97203e0a978bf6856e294"},
      blocks_count: 5_000
    ]

    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_connect(state) do
    timestamp = System.system_time(:millisecond)

    # This first call "warms up" the DB connection
    _ = Fester.Repo.get(Fester.Utxo, "123")
    IO.puts("Warmed up DB connection")

    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_started],
      %{timestamp: timestamp}
    )

    {:ok, state}
  end

  @impl true
  def handle_block(
        %{"height" => 0} = _genesis_block,
        state
      ) do
    IO.puts("Genesis block with no transactions")
    {:ok, :next_block, state}
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
          "current_tip" => %{"slot" => slot},
          "height" => block_height
        } = _block,
        %{is_synced?: false} = state
      ) do
    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_finished],
      %{timestamp: System.system_time(:millisecond)}
    )

    IO.puts("Fully synced NOW. Adding new block to index")
    IO.puts("Blocks count: #{state.blocks_count}")

    Indexer.add_to_index(slot, transactions)

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{timestamp: System.system_time(:millisecond), block_height: block_height}
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
        %{is_synced?: false, blocks_count: 1} = state
      ) do
    Indexer.add_to_index(slot, transactions)
    IO.puts("Progress: #{slot / current_tip_slot * 100}%")

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
        %{is_synced?: false} = state
      ) do
    Indexer.add_to_index(slot, transactions)
    IO.puts("Progress: #{slot / current_tip_slot * 100}%")

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{timestamp: System.system_time(:millisecond), block_height: block_height}
    )

    {:ok, :next_block, %{state | blocks_count: state.blocks_count - 1}}
  end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, state) do
    IO.puts("Handling rollback to slot #{slot}")

    Indexer.rollback_to_slot(slot)
    {:ok, :next_block, state}
  end
end
