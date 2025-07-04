defmodule Fester.Repo.Migrations.CreateUtxos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:utxos, primary_key: false) do
      add :utxo_ref, :string, primary_key: true
      # Some Byron era addresses are huge so we must use text
      # instead of string (varchar 255)
      add :address, :text, null: false
      # Hash of the address is needed for the index.
      add :address_hash, :string, null: false
      add :value, :text, null: false, default: "{}"
      add :created_at_slot, :integer, null: false
      add :consumed_at_slot, :integer, null: true
      # Normally we'd use timestamps() here but since we are using Repo.insert_all,
      # we need to use explicit timestamp fields so we can use a default value for these fields
      # and avoid having to manually set them in Elixir code.
      add :inserted_at, :naive_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :updated_at, :naive_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end

    # Note: Hash generation is now handled in the application code
    # instead of database triggers for better database compatibility

    create_if_not_exists index(:utxos, [:address_hash, :consumed_at_slot],
                           where: "consumed_at_slot IS NULL"
                         )

    create_if_not_exists index(:utxos, [:created_at_slot])
    create_if_not_exists index(:utxos, [:consumed_at_slot, :created_at_slot])
  end
end
