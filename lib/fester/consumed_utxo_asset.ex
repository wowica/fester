defmodule Fester.ConsumedUtxoAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "consumed_utxo_assets" do
    field :utxo_ref, :string, primary_key: true
    field :asset_key, :string, primary_key: true
    field :amount, :integer

    belongs_to :consumed_utxo, Fester.ConsumedUtxo,
      foreign_key: :utxo_ref,
      references: :utxo_ref,
      define_field: false

    timestamps()
  end

  @doc false
  def changeset(consumed_utxo_asset, attrs) do
    consumed_utxo_asset
    |> cast(attrs, [:utxo_ref, :asset_key, :amount])
    |> validate_required([:utxo_ref, :asset_key, :amount])
    |> unique_constraint([:utxo_ref, :asset_key])
    |> validate_number(:amount, greater_than: 0)
  end
end
