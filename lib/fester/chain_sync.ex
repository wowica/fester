defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  # alias Fester.Indexer
  alias Fester.DBIndexer, as: Indexer

  @batch_size 50

  def start_link(opts) do
    initial_state = [
      is_synced?: false,
      # sync_from: :conway,
      sync_from: %{
        point: %{
          slot: 158_284_796,
          id: "a9a2764497d09495176132a5fcff6ad5f2e2226b522698b2cc167a30d03bcb81"
        }
      },
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

    if state.batch do
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
          "slot" => slot
        } = block,
        state
      ) do
    process_transactions_batch = fn
      slot, transaction, current_batch ->
        updated_batch = [{slot, transaction} | current_batch]

        if length(updated_batch) >= @batch_size do
          Indexer.add_to_index_as_batch(updated_batch)

          []
        else
          updated_batch
        end
    end

    updated_batch = process_transactions_batch.(slot, transactions, state.batch)

    :telemetry.execute(
      [:fester, :chain_sync, :block_processed],
      %{
        timestamp: System.system_time(:millisecond),
        block_height: block["height"]
      }
    )

    {:ok, :next_block, %{state | batch: updated_batch}}
  end

  @impl true
  def handle_block(_block, state) do
    {:close, state}
  end

  # @impl true
  # def handle_block(
  #       %{"height" => 0} = _genesis_block,
  #       state
  #     ) do
  #   IO.puts("Genesis block with no transactions")
  #   {:ok, :next_block, state}
  # end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, state) do
    IO.puts("Handling rollback to slot #{slot}")
    Indexer.rollback_to_slot(slot)

    {:ok, :next_block, state}
  end
end
