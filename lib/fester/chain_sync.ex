defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  # alias Fester.Indexer
  alias Fester.DBIndexer, as: Indexer

  @batch_size 50

  def start_link(opts) do
    initial_state = [
      is_synced?: false,
      ## Named eras only work on mainnet
      sync_from: :conway,
      # ## This is the mainnet point to debug collaterals spending
      # sync_from: %{
      #   point: %{
      #     slot: 134_300_210,
      #     id: "cd836ac76601d02411f16d5c4047350c03693f2c735f6bb27a0b1e37f96c666a"
      #   }
      # },
      batch: []
    ]

    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_connect(state) do
    timestamp = System.system_time(:millisecond)

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
          "slot" => slot
        } = _block,
        %{is_synced?: true} = state
      ) do
    IO.puts("Fully synced. Adding new block to index.")

    Indexer.add_to_index(slot, transactions)
    {:ok, :next_block, state}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "current_tip" => %{"slot" => slot}
        } = _block,
        %{is_synced?: false} = state
      ) do
    timestamp = System.system_time(:millisecond)

    :telemetry.execute(
      [:fester, :chain_sync, :catching_up_finished],
      %{timestamp: timestamp}
    )

    if length(state.batch) > 0 do
      # Flush the batch if not empty
      IO.puts("Flushing batch with #{length(state.batch)} transactions")
      updated_batch = [{slot, transactions} | state.batch]

      Indexer.add_to_index_as_batch(updated_batch)
    else
      IO.puts("Adding new block to index")

      Indexer.add_to_index(slot, transactions)
    end

    {:ok, :next_block, %{state | is_synced?: true, batch: []}}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "current_tip" => %{"slot" => current_tip_slot}
        } = _block,
        state
      ) do
    process_transactions_batch = fn
      slot, transaction, current_batch ->
        updated_batch = [{slot, transaction} | current_batch]

        if length(updated_batch) >= @batch_size do
          Indexer.add_to_index_as_batch(updated_batch)
          IO.puts("Flushing batch with #{length(updated_batch)} transactions")
          IO.puts("Progress: #{slot / current_tip_slot * 100}%")

          []
        else
          updated_batch
        end
    end

    updated_batch = process_transactions_batch.(slot, transactions, state.batch)

    {:ok, :next_block, %{state | batch: updated_batch}}
  end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, %{batch: batch} = state) do
    IO.puts("Handling rollback to slot #{slot}")

    if length(batch) > 0 do
      # Flush the batch if not empty. Otherwise, consumed utxos
      # might not be accurate and the restoration might fail.
      IO.puts("But first, flushing batch with #{length(batch)} transactions")

      Indexer.add_to_index_as_batch(batch)
      IO.puts("Flushed batch, proceeding with rollback")
      Indexer.rollback_to_slot(slot)
      {:ok, :next_block, %{state | batch: []}}
    else
      IO.puts("No batch to flush, proceeding with rollback")
      Indexer.rollback_to_slot(slot)
      {:ok, :next_block, state}
    end
  end
end
