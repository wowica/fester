defmodule Fester.Repo do
  use Ecto.Repo,
    otp_app: :fester,
    adapter: Ecto.Adapters.SQLite3
end
