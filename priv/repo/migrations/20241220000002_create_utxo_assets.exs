defmodule Fester.Repo.Migrations.CreateUtxoAssets do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:utxo_assets, primary_key: false) do
      add :utxo_ref, references(:utxos, column: :utxo_ref, type: :string, on_delete: :delete_all),
        null: false

      add :asset_key, :string, null: false
      add :amount, :bigint, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:utxo_assets, [:utxo_ref, :asset_key])
    create_if_not_exists index(:utxo_assets, [:asset_key])
  end
end
