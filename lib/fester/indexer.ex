defmodule Fester.Indexer do
  import Ecto.Query, warn: false

  alias Fester.Repo
  alias Fester.Utxo

  @doc """
  Returns the list of utxos for a given address
  optimized for consumption by blaze-query getUnspentOutputs
  """
  def list_utxos_by_address(address) do
    from(u in Utxo, where: u.address == ^address and is_nil(u.consumed_at_slot))
    |> Repo.all()
    |> Enum.reduce(%{data: []}, &build_response/2)
  end

  defp build_response(%Utxo{utxo_ref: utxo_ref, txout_cbor: cbor}, acc) do
    [tx_hash, index] = String.split(utxo_ref, "#")
    data = Map.get(acc, :data)
    data = [%{tx_hash: tx_hash, index: index, txout_cbor: cbor} | data]

    Map.put(acc, :data, data)
  end

  @doc """
  Returns the balance of assets for a given address.
  """
  def list_assets_by_address(address) do
    from(u in Utxo, where: u.address == ^address and is_nil(u.consumed_at_slot))
    |> Repo.all()
    |> Enum.reduce(%{}, &build_assets_map/2)
  end

  # Helper functions

  defp build_assets_map(%Utxo{value: value}, acc) do
    Enum.reduce(value, acc, fn {policy_id, assets}, acc ->
      Enum.reduce(assets, acc, fn {asset_name, amount}, inner_acc ->
        asset_key = build_asset_key(policy_id, asset_name)
        Map.update(inner_acc, asset_key, amount, &(&1 + amount))
      end)
    end)
  end

  defp build_asset_key(policy_id, ""), do: policy_id
  defp build_asset_key(policy_id, asset_name), do: "#{policy_id}.#{asset_name}"
end
