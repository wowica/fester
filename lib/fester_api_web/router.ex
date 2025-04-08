defmodule FesterAPIWeb.Router do
  use FesterAPIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FesterAPIWeb do
    pipe_through :api
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:fester_api, :dev_routes) do

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
