defmodule Fester.Repo.Migrations.CreateUtxos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:utxos, primary_key: false) do
      add :utxo_ref, :string, primary_key: true
      add :address, :string, null: false
      add :slot, :integer, null: false

      timestamps()
    end

    create_if_not_exists index(:utxos, [:address])
    create_if_not_exists index(:utxos, [:slot])
  end
end
