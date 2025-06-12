defmodule Fester.Repo.Migrations.CreateConsumedUtxoAssets do
  use Ecto.Migration

  def change do
    create table(:consumed_utxo_assets, primary_key: false) do
      add :utxo_ref,
          references(:consumed_utxos, column: :utxo_ref, type: :string, on_delete: :delete_all),
          null: false

      add :asset_key, :string, null: false
      add :amount, :bigint, null: false

      timestamps()
    end

    create unique_index(:consumed_utxo_assets, [:utxo_ref, :asset_key])
    create index(:consumed_utxo_assets, [:asset_key])
  end
end
