defmodule Fester.Indexer do
  import Ecto.Query, warn: false

  alias Fester.Repo
  alias Fester.Utxo
  alias Fester.UtxoAsset

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
    from(u in Utxo, where: u.address == ^address, preload: :utxo_assets)
    |> Repo.all()
  end

  def list_utxos_by_slot(slot) do
    from(u in Utxo, where: u.slot == ^slot, preload: :utxo_assets)
    |> Repo.all()
  end

  @doc """
  Returns aggregated assets for a given address.

  ## Examples

      iex> list_assets_by_address("addr1...")
      %{"policy_id.asset_name" => 1000, ...}

  """
  def list_assets_by_address(address) do
    query =
      from ua in UtxoAsset,
        join: u in Utxo,
        on: ua.utxo_ref == u.utxo_ref,
        where: u.address == ^address,
        group_by: ua.asset_key,
        select: {ua.asset_key, sum(ua.amount)}

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets a single utxo by reference.

  Raises `Ecto.NoResultsError` if the Utxo does not exist.

  ## Examples

      iex> get_utxo!("tx_hash#0")
      %Utxo{}

      iex> get_utxo!("nonexistent")
      ** (Ecto.NoResultsError)

  """
  def get_utxo!(utxo_ref) do
    Utxo
    |> preload(:utxo_assets)
    |> Repo.get!(utxo_ref)
  end

  @doc """
  Gets a single utxo by reference.

  Returns nil if the Utxo does not exist.

  ## Examples

      iex> get_utxo("tx_hash#0")
      %Utxo{}

      iex> get_utxo("nonexistent")
      nil

  """
  def get_utxo(utxo_ref) do
    Utxo
    |> preload(:utxo_assets)
    |> Repo.get(utxo_ref)
  end

  @doc """
  Deletes a Utxo and its associated assets.

  ## Examples

      iex> delete_utxo(utxo)
      {:ok, %Utxo{}}

      iex> delete_utxo(utxo)
      {:error, %Ecto.Changeset{}}

  """
  def delete_utxo(%Utxo{} = utxo) do
    Repo.delete(utxo)
  end
end
