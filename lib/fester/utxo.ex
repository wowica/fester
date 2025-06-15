defmodule Fester.Utxo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:utxo_ref, :string, []}
  @derive {Phoenix.Param, key: :utxo_ref}

  schema "utxos" do
    field :address, :string
    field :slot, :integer

    has_many :utxo_assets, Fester.UtxoAsset, foreign_key: :utxo_ref

    timestamps()
  end

  @doc false
  def changeset(utxo, attrs) do
    utxo
    |> cast(attrs, [:utxo_ref, :address, :slot])
    |> validate_required([:utxo_ref, :address, :slot])
    |> unique_constraint(:utxo_ref, name: "utxos_pkey")
  end
end
