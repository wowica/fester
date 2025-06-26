defmodule Fester.Indexer do
  import Ecto.Query, warn: false

  alias Fester.Repo
  alias Fester.Utxo

  @moduledoc """
  The Indexer context.
  """

  @doc """
  Returns the list of utxos for a given address.

  ## Examples

      iex> list_utxos_by_address("addr1...")
      [%Utxo{}, ...]

  """
  def list_utxos_by_address(address) do
    from(u in Utxo, where: u.address == ^address)
    |> Repo.all()
  end

  def list_utxos_by_slot(slot) do
    from(u in Utxo, where: u.slot == ^slot)
    |> Repo.all()
  end

  @doc """
  Returns aggregated assets for a given address.

  ## Examples

      iex> list_assets_by_address("addr1...")
      %{"policy_id.asset_name" => 1000, ...}

  """

  def list_assets_by_address(address) do
    from(u in Utxo, where: u.address == ^address)
    |> Repo.all()
    |> Enum.reduce(%{}, &build_assets_map/2)
  end

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
