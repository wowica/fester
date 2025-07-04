defmodule Fester.Utxo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:utxo_ref, :string, []}

  schema "utxos" do
    field :address, :string
    field :address_hash, :string
    field :created_at_slot, :integer
    field :consumed_at_slot, :integer
    field :value, :map

    timestamps()
  end

  @doc false
  def changeset(utxo, attrs) do
    utxo
    |> cast(attrs, [:utxo_ref, :address, :created_at_slot, :consumed_at_slot, :value])
    |> validate_required([:utxo_ref, :address, :value, :created_at_slot])
    |> unique_constraint(:utxo_ref, name: "utxos_pkey")
  end

  @doc """
  Generates a SHA256 hash of the address to leverage the db index in the query.
  This function is only used for queries. For inserts, the database handles hash
  generation via triggers.
  """
  def hash_address(address) do
    :crypto.hash(:sha256, address)
    |> Base.encode16(case: :lower)
  end
end
