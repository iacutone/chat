defmodule Chatty.ThousandIsland.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: BroadcastRegistry},
      {Registry, keys: :unique, name: UsernameRegistry},
      {ThousandIsland, [port: 4000, handler_module: Chatty.ThousandIsland.Handler]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chatty.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
