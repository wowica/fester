defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  alias Fester.DBIndexer, as: Indexer

  ###
  # This parameter is the "rollback horizon". It ensures
  # the chain will never be rolled back more than this number of blocks.
  # This value is available on the shelley-genesis.json file as "securityParam".
  ###
  # @security_param_mainnet 2160
  @security_param_testnet 432

  def start_link(opts) do
    initial_state = [
      # Adjust this parameter to the network you are syncing from.
      security_param: @security_param_testnet,
      is_synced?: false,
      ## Named eras only work on mainnet
      # sync_from: :conway,

      sync_from: %{
        point: %{
          slot: 75_587_151,
          id: "caefbb21e1d2618647bd5ab9a6674574dd5948e1294e2e5526569b56b200812b"
        }
      }
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

    IO.puts("Adding new block to index")

    Indexer.add_to_index(slot, transactions)

    {:ok, :next_block, %{state | is_synced?: true, batch: []}}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot,
          "height" => block_height,
          "current_tip" => %{"slot" => current_tip_slot, "height" => tip_height}
        } = _block,
        state
      ) do
    # If the current height is within the rollback horizon, then we should store consumed utxos.
    should_store_consumed_utxos? = tip_height - block_height <= state.security_param

    Indexer.add_to_index(slot, transactions, should_store_consumed_utxos?)

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
