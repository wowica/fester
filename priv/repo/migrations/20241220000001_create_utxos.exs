defmodule Fester.Repo.Migrations.CreateUtxos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:utxos, primary_key: false) do
      add :utxo_ref, :string, primary_key: true
      # Some Byron era addresses are huge so we must use text
      # instead of string (varchar 255)
      add :address, :text, null: false
      add :value, :jsonb, null: false, default: "{}"
      add :created_at_slot, :integer, null: false
      add :consumed_at_slot, :integer, null: true

      # Normally we'd use timestamps() here but since we are using Repo.insert_all,
      # we need to use explicit timestamp fields so we can use a default value for these fields
      # and avoid having to manually set them in Elixir code.
      add :inserted_at, :naive_datetime, null: false, default: fragment("now()")
      add :updated_at, :naive_datetime, null: false, default: fragment("now()")
    end

    create_if_not_exists index(:utxos, [:address, :consumed_at_slot],
                           where: "consumed_at_slot IS NULL"
                         )

    create_if_not_exists index(:utxos, [:created_at_slot])
    create_if_not_exists index(:utxos, [:consumed_at_slot, :created_at_slot])
  end
end
