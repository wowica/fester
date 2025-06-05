defmodule Fester.Indexer.Worker do
  use GenServer

  require Logger

  def child_spec(address: address) do
    %{
      id: :"#{address}",
      start: {__MODULE__, :start_link, [address]},
      type: :worker
    }
  end

  def start_link(address) do
    GenServer.start_link(__MODULE__, address, name: :"#{address}")
  end

  def init(address) do
    Logger.info("Indexer Worker #{address} initialized")

    initial_state = %{
      index: %{},
      address: address,
      # Track consumed UTXOs with their slot info for rollback restoration
      consumed_history: %{},
      # Track the highest processed slot
      highest_slot: 0
    }

    {:ok, initial_state}
  end

  def add_to_index(pid, slot, transactions) do
    GenServer.cast(pid, {:add_to_index, slot, transactions})
  end

  def rollback_to_slot(pid, target_slot) do
    GenServer.call(pid, {:rollback_to_slot, target_slot})
  end

  def list_assets(pid) do
    GenServer.call(pid, :list_assets)
  end

  def handle_call(:list_assets, _from, %{index: index, address: address} = state) do
    outputs = Enum.filter(index, fn {_ref, output} -> output.address == address end)

    assets =
      outputs
      |> Enum.reduce(%{}, fn {_ref, output}, acc ->
        Enum.reduce(output.assets, acc, fn {asset_key, amount}, inner_acc ->
          Map.update(inner_acc, asset_key, amount, &(&1 + amount))
        end)
      end)

    {:reply, assets, state}
  end

  def handle_call({:rollback_to_slot, target_slot}, _from, state) do
    Logger.info("Rolling back to slot #{target_slot} for address #{state.address}")

    new_state = perform_rollback(state, target_slot)

    {:reply, :ok, new_state}
  end

  def handle_cast({:add_to_index, slot, transactions}, %{address: address} = state) do
    # Only process transactions that involve our address
    relevant_transactions =
      Enum.filter(transactions, fn tx ->
        tx["outputs"]
        # One transaction may contain many outputs. If any output is sent to our address,
        # then this is a relevant transaction for us.
        |> Enum.any?(fn output -> output["address"] == address end)
      end)

    new_state = process_transactions(slot, relevant_transactions, state)
    {:noreply, new_state}
  end

  defp perform_rollback(state, target_slot) do
    %{index: index, consumed_history: consumed_history} = state

    # Only keep UTXOs created up to target_slot
    filtered_index =
      Enum.filter(index, fn {_ref, output_data} ->
        output_data.slot <= target_slot
      end)
      |> Enum.into(%{})

    # Read UTXOs consumed after target_slot from consumed_history.
    # These will need to be restored back into the index.
    utxos_to_restore =
      Enum.filter(consumed_history, fn {_ref, consumed_data} ->
        consumed_data.consumed_at_slot > target_slot
      end)

    # Restore UTXOs consumed after target_slot to the index.
    restored_index =
      Enum.reduce(utxos_to_restore, filtered_index, fn {utxo_ref, consumed_data}, acc ->
        Map.put(acc, utxo_ref, %{
          address: consumed_data.address,
          assets: consumed_data.assets,
          slot: consumed_data.original_slot
        })
      end)

    # Clear consumed_history of entries after target_slot.
    filtered_consumed_history =
      Enum.filter(consumed_history, fn {_ref, consumed_data} ->
        consumed_data.consumed_at_slot <= target_slot
      end)
      |> Enum.into(%{})

    %{
      state
      | index: restored_index,
        consumed_history: filtered_consumed_history,
        highest_slot: target_slot
    }
  end

  defp process_transactions(slot, transactions, state) do
    Enum.reduce(transactions, state, &process_transaction(slot, &1, &2))
  end

  defp process_transaction(slot, transaction, state) do
    %{"id" => tx_id, "inputs" => inputs, "outputs" => outputs} = transaction

    # Process inputs (consume UTXOs)
    state = process_transaction_inputs(slot, inputs, state)

    # Process outputs (create UTXOs)
    state = process_transaction_outputs(slot, outputs, tx_id, state)

    # Update highest processed slot
    %{state | highest_slot: max(state.highest_slot, slot)}
  end

  # Inputs are UTXOs consumed by the transaction, so we
  # remove them from the index and add them to consumed_history
  defp process_transaction_inputs(slot, inputs, state) do
    Enum.reduce(inputs, state, fn %{"index" => idx, "transaction" => %{"id" => tx_hash}},
                                  acc_state ->
      input_ref = "#{tx_hash}##{idx}"

      case Map.get(acc_state.index, input_ref) do
        nil ->
          # UTXO not in our index (doesn't belong to our address)
          acc_state

        utxo_data ->
          # Move UTXO from index to consumed_history
          new_consumed_history =
            Map.put(acc_state.consumed_history, input_ref, %{
              address: utxo_data.address,
              assets: utxo_data.assets,
              original_slot: utxo_data.slot,
              consumed_at_slot: slot
            })

          new_index = Map.delete(acc_state.index, input_ref)

          %{acc_state | index: new_index, consumed_history: new_consumed_history}
      end
    end)
  end

  # Outputs are UTXOs created by the transaction, so we
  # add them to the index with slot information
  defp process_transaction_outputs(slot, outputs, tx_id, state) do
    %{index: index, address: target_address} = state

    {new_index, _} =
      Enum.reduce(outputs, {index, 0}, fn output, {acc_index, idx} ->
        output_ref = "#{tx_id}##{idx}"
        %{"address" => address, "value" => value} = output

        new_acc_index =
          if address == target_address do
            assets = build_assets_map(value)

            Map.put(acc_index, output_ref, %{
              address: address,
              assets: assets,
              slot: slot
            })
          else
            acc_index
          end

        {new_acc_index, idx + 1}
      end)

    %{state | index: new_index}
  end

  defp build_assets_map(value) do
    Enum.reduce(value, %{}, fn {policy_id, assets}, acc ->
      Enum.reduce(assets, acc, fn {asset_name, amount}, inner_acc ->
        asset_key = build_asset_key(policy_id, asset_name)
        Map.put(inner_acc, asset_key, amount)
      end)
    end)
  end

  defp build_asset_key(policy_id, ""), do: policy_id
  defp build_asset_key(policy_id, asset_name), do: "#{policy_id}.#{asset_name}"
end
