defmodule Fester.Repo.Migrations.AddValueToUtxos do
  use Ecto.Migration

  def change do
    alter table(:utxos) do
      add :value, :jsonb, null: false, default: "{}"
    end

    alter table(:consumed_utxos) do
      add :value, :jsonb, null: false, default: "{}"
    end
  end
end
