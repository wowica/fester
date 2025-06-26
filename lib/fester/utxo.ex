defmodule Fester.Utxo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:utxo_ref, :string, []}
  @derive {Phoenix.Param, key: :utxo_ref}

  schema "utxos" do
    field :address, :string
    field :slot, :integer
    field :value, :map

    timestamps()
  end

  @doc false
  def changeset(utxo, attrs) do
    utxo
    |> cast(attrs, [:utxo_ref, :address, :slot, :value])
    |> validate_required([:utxo_ref, :address, :slot])
    |> unique_constraint(:utxo_ref, name: "utxos_pkey")
  end
end
