defmodule Fester.Repo.Migrations.CreateCustomTypes do
  use Ecto.Migration

  def change do
    # https://github.com/IntersectMBO/cardano-db-sync/blob/da764296943a1de65a5085810bf70f55e6bda289/schema/migration-1-0004-20201026.sql#L15-L16
    execute "CREATE DOMAIN int65type AS numeric (20, 0) CHECK (VALUE >= -18446744073709551615 AND VALUE <= 18446744073709551615);"
  end
end
