defmodule Fester.DBIndexer do
  @moduledoc """
  This module is responsible for updating the addresses index with the latest transactions.
  """

  import Ecto.Query
  alias Fester.Repo
  alias Fester.Utxo
  alias Fester.UtxoAsset
  alias Fester.ConsumedUtxo
  alias Fester.ConsumedUtxoAsset

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
    Enum.each(transactions, fn transaction ->
      case process_transaction(slot, transaction, _store_consumed_utxos? = true) do
        :ok ->
          :ok

        {:error, reason} ->
          Repo.rollback("Transaction processing failed: #{inspect(reason)}")
      end
    end)
  end

  def add_to_index_as_batch(transactions_batch, store_consumed_utxos? \\ true) do
    Enum.each(transactions_batch, fn {slot, transactions} ->
      Enum.each(transactions, fn transaction ->
        case process_transaction(slot, transaction, store_consumed_utxos?) do
          :ok ->
            :ok

          {:error, reason} ->
            Repo.rollback("Transaction processing failed: #{inspect(reason)}")
        end
      end)
    end)
  end

  @doc """
  Rolls back the index to a given slot.
  Takes a target slot number as input.
  """
  @spec rollback_to_slot(integer()) :: :ok | {:error, any()}
  def rollback_to_slot(target_slot) do
    Repo.transaction(fn ->
      with :ok <- delete_utxos_after_slot(target_slot),
           :ok <- restore_consumed_utxos_after_slot(target_slot),
           :ok <- cleanup_consumed_history_after_slot(target_slot) do
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
         %{"spends" => "collaterals", "id" => tx_id} = transaction,
         store_consumed_utxos?
       ) do
    Logger.info("Processing transaction with collaterals")

    %{"collaterals" => collaterals_as_inputs} = transaction

    # Wrapping the collateral return in a list to make it consistent with the
    # other calling of the process_transaction_outputs function.
    collateral_return_as_outputs =
      if transaction["collateral_return"], do: [transaction["collateral_return"]], else: []

    with :ok <- process_transaction_inputs(slot, collaterals_as_inputs, store_consumed_utxos?),
         :ok <- process_transaction_outputs(slot, collateral_return_as_outputs, tx_id) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process collaterals: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_transaction(slot, transaction, store_consumed_utxos?) do
    %{
      "id" => tx_id,
      "inputs" => inputs,
      "outputs" => outputs
    } = transaction

    with :ok <- process_transaction_inputs(slot, inputs, store_consumed_utxos?),
         :ok <- process_transaction_outputs(slot, outputs, tx_id) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process transaction: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_transaction_inputs(slot, inputs, store_consumed_utxos?) do
    inputs
    |> Enum.reduce_while(:ok, fn %{"index" => idx, "transaction" => %{"id" => tx_hash}}, acc ->
      input_ref = "#{tx_hash}##{idx}"

      case process_single_input(slot, input_ref, store_consumed_utxos?) do
        :ok ->
          {:cont, acc}

        {:error, reason} ->
          Logger.error("Failed to process input #{input_ref}: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp process_single_input(slot, input_ref, store_consumed_utxos?) do
    case Repo.get(Utxo, input_ref) do
      nil ->
        # UTXO not in our database (doesn't belong to tracked addresses)
        :ok

      utxo ->
        # Preload assets upfront to avoid N+1 queries
        utxo = Repo.preload(utxo, :utxo_assets)

        # Store consumed UTXO data for rollback capability
        consumed_utxo_attrs = %{
          utxo_ref: utxo.utxo_ref,
          address: utxo.address,
          original_slot: utxo.slot,
          consumed_at_slot: slot
        }

        with {:ok, _consumed_utxo} <-
               insert_consumed_utxo(consumed_utxo_attrs, store_consumed_utxos?),
             :ok <- store_consumed_assets(utxo.utxo_assets, store_consumed_utxos?),
             {count, _} when count > 0 <-
               from(u in Utxo, where: u.utxo_ref == ^input_ref)
               |> Repo.delete_all() do
          :ok
        else
          {:error, reason} -> {:error, reason}
          {0, _} -> {:error, "Failed to delete UTXO #{input_ref}"}
        end
    end
  end

  defp store_consumed_assets(_utxo_assets, false = _store_consumed_utxos?), do: :ok

  defp store_consumed_assets(utxo_assets, _store_consumed_utxos?) do
    utxo_assets
    |> Enum.reduce_while(:ok, fn utxo_asset, acc ->
      consumed_asset_attrs = %{
        utxo_ref: utxo_asset.utxo_ref,
        asset_key: utxo_asset.asset_key,
        amount: utxo_asset.amount
      }

      case insert_consumed_utxo_asset(consumed_asset_attrs) do
        {:ok, _} -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp process_transaction_outputs(slot, outputs, tx_id) do
    outputs
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {output, idx}, acc ->
      output_ref = "#{tx_id}##{idx}"
      %{"address" => address, "value" => value} = output

      case process_single_output(slot, output_ref, address, value) do
        :ok ->
          {:cont, acc}

        {:error, reason} ->
          Logger.error("Failed to process output #{output_ref}: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp process_single_output(slot, output_ref, address, value) do
    utxo_attrs = %{
      utxo_ref: output_ref,
      address: address,
      slot: slot
    }

    assets = build_assets_map(value)

    with {:ok, _utxo} <- insert_utxo(utxo_attrs),
         :ok <- store_utxo_assets(output_ref, assets) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp store_utxo_assets(output_ref, assets) do
    assets
    |> Enum.reduce_while(:ok, fn {asset_key, amount}, acc ->
      asset_attrs = %{
        utxo_ref: output_ref,
        asset_key: asset_key,
        amount: amount
      }

      case insert_utxo_asset(asset_attrs) do
        {:ok, _} -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Rollback helper functions

  defp delete_utxos_after_slot(target_slot) do
    # Delete UTXOs after target_slot (cascade will automatically delete associated assets)
    case from(u in Utxo, where: u.slot > ^target_slot)
         |> Repo.delete_all() do
      {_count, _} -> :ok
      error -> {:error, "Failed to delete UTXOs: #{inspect(error)}"}
    end
  end

  defp restore_consumed_utxos_after_slot(target_slot) do
    # Find consumed UTXOs that were consumed after target_slot (for all addresses)
    consumed_utxos_to_restore =
      from(cu in ConsumedUtxo,
        where: cu.consumed_at_slot > ^target_slot,
        preload: [:consumed_utxo_assets]
      )
      |> Repo.all()

    # Restore each consumed UTXO back to the active UTXOs table
    consumed_utxos_to_restore
    |> Enum.reduce_while(:ok, fn consumed_utxo, acc ->
      utxo_attrs = %{
        utxo_ref: consumed_utxo.utxo_ref,
        address: consumed_utxo.address,
        slot: consumed_utxo.original_slot
      }

      case insert_utxo(utxo_attrs) do
        {:ok, _utxo} ->
          # Restore the assets
          case restore_utxo_assets(consumed_utxo.consumed_utxo_assets) do
            :ok -> {:cont, acc}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, reason} ->
          Logger.error(
            "Failed to restore UTXO with attributes #{inspect(utxo_attrs)}: #{inspect(reason)}"
          )

          {:halt, {:error, reason}}
      end
    end)
  end

  defp restore_utxo_assets(consumed_assets) do
    consumed_assets
    |> Enum.reduce_while(:ok, fn consumed_asset, acc ->
      asset_attrs = %{
        utxo_ref: consumed_asset.utxo_ref,
        asset_key: consumed_asset.asset_key,
        amount: consumed_asset.amount
      }

      case insert_utxo_asset(asset_attrs) do
        {:ok, _} ->
          {:cont, acc}

        {:error, reason} ->
          Logger.error(
            "Failed to restore UTXO assets with attributes #{inspect(asset_attrs)}: #{inspect(reason)}"
          )

          {:halt, {:error, reason}}
      end
    end)
  end

  defp cleanup_consumed_history_after_slot(target_slot) do
    # Delete consumed UTXOs after target_slot (cascade will automatically delete associated assets)
    case from(cu in ConsumedUtxo, where: cu.consumed_at_slot > ^target_slot)
         |> Repo.delete_all() do
      {_count, _} -> :ok
      error -> {:error, "Failed to delete consumed UTXOs: #{inspect(error)}"}
    end
  end

  defp insert_utxo(attrs) do
    %Utxo{}
    |> Utxo.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_consumed_utxo(_attrs, false = _store_consumed_utxos?), do: {:ok, nil}

  defp insert_consumed_utxo(attrs, _store_consumed_utxos?) do
    %ConsumedUtxo{}
    |> ConsumedUtxo.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_consumed_utxo_asset(attrs) do
    %ConsumedUtxoAsset{}
    |> ConsumedUtxoAsset.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_utxo_asset(attrs) do
    %UtxoAsset{}
    |> UtxoAsset.changeset(attrs)
    |> Repo.insert()
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
