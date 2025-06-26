defmodule Fester.Repo.Migrations.DropUtxoAssets do
  use Ecto.Migration

  def change do
    drop_if_exists table(:utxo_assets)
    drop_if_exists table(:consumed_utxo_assets)
  end
end
