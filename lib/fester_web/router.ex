defmodule FesterWeb.Router do
  use FesterWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FesterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FesterWeb do
    pipe_through :browser

    live "/dashboard", DashboardLive
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
