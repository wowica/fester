defmodule Fester.DBIndexer do
  @moduledoc """
  This module is responsible for updating the addresses index with the latest transactions.
  """

  import Ecto.Query
  alias Fester.Repo
  alias Fester.Utxo

  require Logger

  ## Public API
  ## The public API of this module is composed of two functions:
  ## 1. add_to_index/2
  ## 2. rollback_to_slot/1

  @doc """
  Processes transactions in a block by inserting output assets and removing consumed inputs from the database.
  Takes a slot number and list of transactions as input.
  """
  @spec add_to_index(integer(), list(map())) :: :ok | {:error, any()}
  def add_to_index(slot, transactions) do
    Repo.transaction(fn ->
      Enum.each(transactions, fn transaction ->
        :telemetry.execute(
          [:fester, :db_indexer, :tx_start],
          %{timestamp: System.system_time(:millisecond)}
        )

        case process_transaction(slot, transaction) do
          :ok ->
            :telemetry.execute(
              [:fester, :db_indexer, :tx_end],
              %{timestamp: System.system_time(:millisecond)}
            )

            :ok

          {:error, reason} ->
            Repo.rollback("Transaction processing failed: #{inspect(reason)}")
        end
      end)
    end)
  end

  @doc """
  Rolls back the index to a given slot.

  The rollback process is as follows:
  1. Delete UTXOs created after the target slot
  2. Restore UTXOs that were consumed after the target slot AND originally created before or at target_slot

  Takes a target slot number as input.
  """
  @spec rollback_to_slot(integer()) :: :ok | {:error, any()}
  def rollback_to_slot(target_slot) do
    Repo.transaction(fn ->
      with :ok <- delete_utxos_after_slot(target_slot),
           :ok <- restore_consumed_utxos_after_slot(target_slot) do
        Logger.info("Successfully completed rollback to slot #{target_slot}")
        :ok
      else
        {:error, reason} ->
          Logger.error("Rollback failed to slot #{target_slot}: #{inspect(reason)}")
          Repo.rollback("Rollback failed: #{inspect(reason)}")
      end
    end)
  end

  ## Private helper functions

  ## When collaterals are spent, this means phase-2 validation failed and the transaction
  ## did not spend from the contract. Only the collateral input must be processed,
  ## and no output address in the transactionshould be receiving it.
  defp process_transaction(
         slot,
         %{"spends" => "collaterals", "id" => tx_id} = transaction
       ) do
    Logger.info("Processing transaction with collaterals")

    %{"collaterals" => collaterals_as_inputs} = transaction

    # Wrapping the collateral return in a list to make it consistent with the
    # other calling of the process_transaction_outputs function.
    collateral_return_as_outputs =
      if transaction["collateral_return"], do: [transaction["collateral_return"]], else: []

    with :ok <- process_transaction_inputs(slot, collaterals_as_inputs),
         :ok <- process_transaction_outputs(slot, collateral_return_as_outputs, tx_id) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process collaterals: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_transaction(slot, transaction) do
    %{
      "id" => tx_id,
      "inputs" => inputs,
      "outputs" => outputs
    } = transaction

    with :ok <- process_transaction_inputs(slot, inputs),
         :ok <- process_transaction_outputs(slot, outputs, tx_id) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process transaction: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Marks inputs as consumed
  defp process_transaction_inputs(slot, inputs) do
    :telemetry.execute(
      [:fester, :db_indexer, :tx_inputs_start],
      %{timestamp: System.system_time(:millisecond)}
    )

    input_refs =
      inputs
      |> Enum.map(fn %{"index" => idx, "transaction" => %{"id" => tx_hash}} ->
        "#{tx_hash}##{idx}"
      end)

    {updated_count, _} =
      from(utxo in Utxo, where: utxo.utxo_ref in ^input_refs)
      |> Repo.update_all(set: [consumed_at_slot: slot])

    if updated_count < length(input_refs) do
      Logger.debug(
        "#{length(input_refs) - updated_count} UTXOs were not found in database (likely untracked from partial sync)"
      )
    end

    :telemetry.execute(
      [:fester, :db_indexer, :tx_inputs_end],
      %{timestamp: System.system_time(:millisecond)}
    )

    :ok
  end

  defp process_transaction_outputs(_slot, [] = _outputs, _tx_id), do: :ok

  defp process_transaction_outputs(slot, outputs, tx_id) do
    utxo_attrs_list =
      outputs
      |> Enum.with_index()
      |> Enum.map(fn {output, idx} ->
        output_ref = "#{tx_id}##{idx}"
        %{"address" => address, "value" => value} = output

        %{
          utxo_ref: output_ref,
          address: address,
          value: value,
          created_at_slot: slot
        }
      end)

    # Batch insert all UTXOs in a single database operation
    {inserted_count, _} = Repo.insert_all(Utxo, utxo_attrs_list)

    if inserted_count != length(outputs) do
      Logger.warning("Expected to insert #{length(outputs)} UTXOs but inserted #{inserted_count}")
    end

    :ok
  end

  # Rollback helper functions

  defp delete_utxos_after_slot(target_slot) do
    case from(u in Utxo, where: u.created_at_slot > ^target_slot)
         |> Repo.delete_all() do
      {_count, _} -> :ok
      error -> {:error, "Failed to delete UTXOs: #{inspect(error)}"}
    end
  end

  defp restore_consumed_utxos_after_slot(target_slot) do
    # Restored UTXOs that were consumed after target_slot AND originally created before or at target_slot
    {count, _} =
      from(utxo in Utxo,
        where: utxo.consumed_at_slot > ^target_slot and utxo.created_at_slot <= ^target_slot
      )
      |> Repo.update_all(set: [consumed_at_slot: nil])

    Logger.info("Restored #{count} consumed UTXOs for rollback to slot #{target_slot}")
  end
end
