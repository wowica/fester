defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  alias Fester.DBIndexer, as: Indexer

  def start_link(opts) do
    initial_state = [
      is_synced?: false,
      sync_from: :origin
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
    timestamp = System.system_time(:millisecond)

    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_finished],
      %{timestamp: timestamp}
    )

    IO.puts("Fully synced NOW. Adding new block to index")

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
        %{is_synced?: false} = state
      ) do
    Indexer.add_to_index(slot, transactions)
    IO.puts("Progress: #{slot / current_tip_slot * 100}%")

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{timestamp: System.system_time(:millisecond), block_height: block_height}
    )

    {:ok, :next_block, state}
  end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, state) do
    IO.puts("Handling rollback to slot #{slot}")

    Indexer.rollback_to_slot(slot)
    {:ok, :next_block, state}
  end
end
