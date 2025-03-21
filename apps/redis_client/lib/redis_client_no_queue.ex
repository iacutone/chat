defmodule RedisClientNoQueue do
  use GenServer

  require Logger

  alias RedisClient.RESP

  defstruct [:host, :port, :socket, :caller_monitor]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    inital_state = %__MODULE__{
      host: Keyword.fetch!(opts, :host),
      port: Keyword.fetch!(opts, :port)
    }

    {:ok, inital_state, {:continue, :connect}}
  end

  def handle_continue(:connect, state) do
    tcp_opts = [:binary, active: :once]

    case :gen_tcp.connect(state.host, state.port, tcp_opts, 5_000) do
      {:ok, socket} ->
        {:noreply, %__MODULE__{state | socket: socket}}

      {:error, reason} ->
        Logger.error("Failed to connect: #{:inet.format_error(reason)}")
        Process.send_after(self(), :reconnect, 1_000)
        {:noreply, state}
    end
  end

  def handle_info(message, state)

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Process.send_after(self(), :reconnect, 1_000)
    {:noreply, %__MODULE__{state | socket: nil}}
  end

  def handle_info({:tcp_error, socket, _reason}, %{socket: socket} = state) do
    Process.send_after(self(), :reconnect, 1_000)
    {:noreply, %__MODULE__{state | socket: nil}}
  end

  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info({:DOWN, ref, _, _, _}, %{caller_monitor: ref}, state) do
    :ok = :inet.setopts(state.socket, active: :once)
    {:noreply, %{state | caller_monitor: nil}}
  end

  def command(client, command) do
    case GenServer.call(client, :checkout) do
      {:ok, socket} ->
        result =
          with :ok <- :gen_tcp.send(socket, RESP.encode(command)),
               {:ok, data} <- receive_response(socket, &RESP.decode/1) do
            {:ok, data}
          else
            {:error, reason} ->
              {:error, reason}
          end

        GenServer.call(client, :checkin)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp receive_response(socket, continuation) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        case continuation.(data) do
          {:ok, response, _rest = ""} ->
            {:ok, response}

          {:continuation, new_continuation} ->
            receive_response(socket, new_continuation)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_call(:checkout, _from, %{socket: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:checkin, _from, state) do
    Process.demonitor(state.caller_monitor, [:flush])
    :ok = :inet.setopts(state.socket, active: :once)
    {:reply, :ok, %{state | caller_monitor: nil}}
  end
end
