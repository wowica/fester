defmodule Fester.ChainSync do
  use Xogmios, :chain_sync

  # alias Fester.Indexer
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

    Indexer.add_to_index(slot, transactions)
    {:ok, :next_block, %{state | is_synced?: true}}
  end

  @impl true
  def handle_block(
        %{
          "transactions" => transactions,
          "slot" => slot
        } = _block,
        state
      ) do
    IO.puts("Handling new block (#{slot})")
    Indexer.add_to_index(slot, transactions)

    {:ok, :next_block, state}
  end

  @impl true
  def handle_block(
        %{"height" => 0} = _genesis_block,
        state
      ) do
    IO.puts("Genesis block with no transactions")
    {:ok, :next_block, state}
  end

  @impl true
  def handle_rollback(%{"slot" => slot} = _point, state) do
    IO.puts("Handling rollback to slot #{slot}")
    Indexer.rollback_to_slot(slot)

    {:ok, :next_block, state}
  end
end
