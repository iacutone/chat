defmodule SillyGame.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/websocket" do
    conn
    |> WebSockAdapter.upgrade(SillyGame.Server, [], timeout: 600_000)
    |> halt()
  end
end
