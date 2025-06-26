defmodule Fester.Repo.Migrations.CreateUtxos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:utxos, primary_key: false) do
      add :utxo_ref, :string, primary_key: true
      add :address, :string, null: false
      add :created_at_slot, :integer, null: false
      add :consumed_at_slot, :integer, null: true

      timestamps()
    end

    create_if_not_exists index(:utxos, [:address])
    create_if_not_exists index(:utxos, [:created_at_slot])
    create_if_not_exists index(:utxos, [:consumed_at_slot])
  end
end
