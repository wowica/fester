defmodule Fester.Repo.Migrations.AddTxoutCborToUtxos do
  use Ecto.Migration

  def change do
    alter table(:utxos) do
      add :txout_cbor, :text, null: false
    end
  end
end
