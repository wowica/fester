defmodule Fester.ConsumedUtxo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:utxo_ref, :string, []}
  @derive {Phoenix.Param, key: :utxo_ref}

  schema "consumed_utxos" do
    field :address, :string
    field :original_slot, :integer
    field :consumed_at_slot, :integer

    has_many :consumed_utxo_assets, Fester.ConsumedUtxoAsset, foreign_key: :utxo_ref

    timestamps()
  end

  @doc false
  def changeset(consumed_utxo, attrs) do
    consumed_utxo
    |> cast(attrs, [:utxo_ref, :address, :original_slot, :consumed_at_slot])
    |> validate_required([:utxo_ref, :address, :original_slot, :consumed_at_slot])
    |> unique_constraint(:utxo_ref)
    |> validate_number(:original_slot, greater_than: 0)
    |> validate_number(:consumed_at_slot, greater_than: 0)
  end
end
