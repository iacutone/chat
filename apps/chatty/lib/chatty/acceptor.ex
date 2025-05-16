defmodule Chatty.Acceptor do
  use GenServer

  require Logger

  defstruct [:listen_socket, :supervisor]

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(options) do
    port = Keyword.fetch!(options, :port)

    listen_options = [
      :binary,
      active: :once,
      exit_on_close: false,
      reuseaddr: true,
      backlog: 25,
      cacertfile: Application.app_dir(:chatty, "priv/ca.pem"),
      certfile: Application.app_dir(:chatty, "priv/server.crt"),
      keyfile: Application.app_dir(:chatty, "priv/server.key")
    ]

    {:ok, sup} = DynamicSupervisor.start_link(max_children: 20)

    case :ssl.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started chat server on port #{port}")
        send(self(), :accept)
        {:ok, %__MODULE__{listen_socket: listen_socket, supervisor: sup}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_info(:accept, state) do
    case :ssl.transport_accept(state.listen_socket, 2_000) do
      {:ok, socket} ->
        {:ok, pid} = DynamicSupervisor.start_child(state.supervisor, {Chatty.Connection, socket})

        :ok = :ssl.controlling_process(socket, pid)

        send(self(), :accept)
        {:noreply, state}

      {:error, :timeout} ->
        send(self(), :accept)
        {:noreply, state}

      {:error, reason} ->
        {:noreply, reason, state}
    end
  end
end
