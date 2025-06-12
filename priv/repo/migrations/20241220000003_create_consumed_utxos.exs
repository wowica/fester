defmodule Fester.Repo.Migrations.CreateConsumedUtxos do
  use Ecto.Migration

  def change do
    create table(:consumed_utxos, primary_key: false) do
      add :utxo_ref, :string, primary_key: true
      add :address, :string, null: false
      add :original_slot, :integer, null: false
      add :consumed_at_slot, :integer, null: false

      timestamps()
    end

    create index(:consumed_utxos, [:consumed_at_slot])
    create index(:consumed_utxos, [:original_slot])
    create index(:consumed_utxos, [:address])
  end
end
