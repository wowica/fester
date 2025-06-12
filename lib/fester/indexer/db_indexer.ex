defmodule Fester.DBIndexer do
  @moduledoc """
  This module is responsible for updating the database index with the latest transactions.
  """

  import Ecto.Query
  alias Fester.Repo
  alias Fester.Utxo
  alias Fester.UtxoAsset
  alias Fester.ConsumedUtxo
  alias Fester.ConsumedUtxoAsset

  require Logger

  @doc """
  Processes transactions in a block by inserting output assets and removing consumed inputs from the database.
  Takes a slot number and list of transactions as input.
  """
  def add_to_index(slot, transactions) do
    Repo.transaction(fn ->
      Enum.each(transactions, fn transaction ->
        case process_transaction(slot, transaction) do
          :ok ->
            :ok

          {:error, reason} ->
            Repo.rollback("Transaction processing failed: #{inspect(reason)}")
        end
      end)
    end)
  end

  defp process_transaction(slot, transaction) do
    %{"id" => tx_id, "inputs" => inputs, "outputs" => outputs} = transaction

    with :ok <- process_transaction_inputs(slot, inputs),
         :ok <- process_transaction_outputs(slot, outputs, tx_id) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process transaction: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_transaction_inputs(slot, inputs) do
    inputs
    |> Enum.reduce_while(:ok, fn %{"index" => idx, "transaction" => %{"id" => tx_hash}}, acc ->
      input_ref = "#{tx_hash}##{idx}"

      case process_single_input(slot, input_ref) do
        :ok ->
          {:cont, acc}

        {:error, reason} ->
          Logger.error("Failed to process input #{input_ref}: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp process_single_input(slot, input_ref) do
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

        with {:ok, _consumed_utxo} <- insert_consumed_utxo(consumed_utxo_attrs),
             :ok <- store_consumed_assets(utxo.utxo_assets),
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

  defp store_consumed_assets(utxo_assets) do
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
    # Insert new UTXO using Ecto
    utxo_attrs = %{
      utxo_ref: output_ref,
      address: address,
      slot: slot
    }

    # Build assets map
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

  defp insert_utxo(attrs) do
    %Utxo{}
    |> Utxo.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_consumed_utxo(attrs) do
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
