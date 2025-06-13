defmodule Fester.UtxoAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  alias Fester.CardanoTypes.Int65Type

  schema "utxo_assets" do
    field :utxo_ref, :string, primary_key: true
    field :asset_key, :string, primary_key: true
    field :amount, Int65Type

    belongs_to :utxo, Fester.Utxo,
      foreign_key: :utxo_ref,
      references: :utxo_ref,
      define_field: false

    timestamps()
  end

  @doc false
  def changeset(utxo_asset, attrs) do
    utxo_asset
    |> cast(attrs, [:utxo_ref, :asset_key, :amount])
    |> validate_required([:utxo_ref, :asset_key, :amount])
    |> unique_constraint([:utxo_ref, :asset_key])
  end
end
