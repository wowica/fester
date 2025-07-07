defmodule FesterWeb.Router do
  use FesterWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FesterWeb do
    pipe_through :api

    # Lists assets for an address
    get "/address/:address/assets", AssetsController, :index
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:fester, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
