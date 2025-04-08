defmodule FesterAPI.Repo do
  use Ecto.Repo,
    otp_app: :fester_api,
    adapter: Ecto.Adapters.Postgres
end
