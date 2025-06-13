defmodule Fester.CardanoTypes do
  # https://github.com/IntersectMBO/cardano-db-sync/blob/da764296943a1de65a5085810bf70f55e6bda289/schema/migration-1-0004-20201026.sql#L15-L16
  defmodule Int65Type do
    use Ecto.Type

    def type, do: :decimal

    def cast(value) when is_integer(value) do
      {:ok, Decimal.new(value)}
    end

    def cast(value) when is_binary(value) do
      case Integer.parse(value) do
        {int, _} -> {:ok, Decimal.new(int)}
        :error -> :error
      end
    end

    def cast(%Decimal{} = value), do: {:ok, value}
    def cast(_), do: :error

    def load(%Decimal{} = value), do: {:ok, value}
    def load(value) when is_binary(value), do: {:ok, Decimal.new(value)}
    def load(_), do: :error

    def dump(%Decimal{} = value), do: {:ok, value}
    def dump(value) when is_integer(value), do: {:ok, Decimal.new(value)}
    def dump(_), do: :error
  end
end
