defmodule Fester.DBIndexer do
  @moduledoc """
  This module is responsible for writes and reads from the database.
  """

  import Ecto.Query
  alias Fester.Repo
  alias Fester.Utxo
  alias Fester.UtxoAsset

  @doc """
  This function takes an absolute slot and a list of transactions for a given block as input.
  This function processes outputs extracted from transactions and inserts the assets found in those outputs into the database, associated with the address that holds them.
  This function also deletes inputs extracted from the given transactions from the addresses that hold them.
  """
  def add_to_index(slot, transactions) do
    Repo.transaction(fn ->
      Enum.each(transactions, fn transaction ->
        process_transaction(slot, transaction)
      end)
    end)
  end

  defp process_transaction(slot, transaction) do
    %{"id" => tx_id, "inputs" => inputs, "outputs" => outputs} = transaction

    # Process inputs (delete consumed UTXOs)
    process_transaction_inputs(inputs)

    # Process outputs (insert new UTXOs)
    process_transaction_outputs(slot, outputs, tx_id)
  end

  defp process_transaction_inputs(inputs) do
    Enum.each(inputs, fn %{"index" => idx, "transaction" => %{"id" => tx_hash}} ->
      input_ref = "#{tx_hash}##{idx}"

      # Delete consumed UTXO (cascade will automatically delete related assets)
      from(u in Utxo, where: u.utxo_ref == ^input_ref)
      |> Repo.delete_all()
    end)
  end

  defp process_transaction_outputs(slot, outputs, tx_id) do
    outputs
    |> Enum.with_index()
    |> Enum.each(fn {output, idx} ->
      output_ref = "#{tx_id}##{idx}"
      %{"address" => address, "value" => value} = output

      # Insert new UTXO using Ecto
      utxo_attrs = %{
        utxo_ref: output_ref,
        address: address,
        slot: slot
      }

      {:ok, _utxo} =
        %Utxo{}
        |> Utxo.changeset(utxo_attrs)
        |> Repo.insert()

      # Build assets map and insert each asset
      assets = build_assets_map(value)

      Enum.each(assets, fn {asset_key, amount} ->
        asset_attrs = %{
          utxo_ref: output_ref,
          asset_key: asset_key,
          amount: amount
        }

        %UtxoAsset{}
        |> UtxoAsset.changeset(asset_attrs)
        |> Repo.insert!()
      end)
    end)
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
