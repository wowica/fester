defmodule Fester.Indexer do
  import Ecto.Query, warn: false

  alias Fester.Repo
  alias Fester.Utxo

  @doc """
  Returns the list of utxos for a given address.
  """
  def list_utxos_by_address(address) do
    from(u in Utxo, where: u.address == ^address and is_nil(u.consumed_at_slot))
    |> Repo.all()
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
