defmodule Chatty.Connection do
  use GenServer, restart: :temporary

  require Logger

  alias Chat.Message.Broadcast
  alias Chat.Message.Register
  alias Chat.Protocol

  defstruct [:socket, :username, buffer: <<>>]

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, %__MODULE__{socket: socket}}
  end

  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    state = update_in(state.buffer, &(&1 <> data))
    :ok = :inet.setopts(socket, active: :once)
    handle_new_data(state)
  end

  def handle_info({:broadcast, message}, state) do
    encoded_message = Protocol.encode_message(message)
    :ok = :gen_tcp.send(state.socket, encoded_message)
    {:noreply, state}
  end

  def handle_message(%Register{username: username}, %__MODULE__{username: nil} = state) do
    {:ok, _} = Registry.register(BroadcastRegistry, :broadcast, :novalue)
    {:ok, _} = Registry.register(UsernameRegistry, username, :novalue)
    {:ok, put_in(state.username, username)}
  end

  def handle_message(%Broadcast{} = message, state) do
    sender = self()
    message = %Broadcast{message | from_username: state.username}

    Registry.dispatch(BroadcastRegistry, :broadcast, fn entries ->
      Enum.each(entries, fn {pid, _value} ->
        if pid != sender do
          send(pid, {:broadcast, message})
        end
      end)
    end)

    {:ok, state}
  end

  def handle_message(%Register{}, _) do
    Logger.error("Invalid Register message, had already recceived one")
    :error
  end

  defp handle_new_data(state) do
    case Protocol.decode_message(state.buffer) do
      {:ok, message, rest} ->
        state = put_in(state.buffer, rest)

        case handle_message(message, state) do
          {:ok, state} -> handle_new_data(state)
          :error -> {:stop, :normal, state}
        end

      :incomplete ->
        {:noreply, state}

      :error ->
        {:stop, :normal, state}
    end
  end
end
