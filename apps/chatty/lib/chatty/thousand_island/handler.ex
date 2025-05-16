defmodule Chatty.ThousandIsland.Handler do
  use ThousandIsland.Handler

  require Logger

  alias Chatty.Connection
  alias Chatty.Protocol
  alias Chatty.Message.Broadcast

  defstruct [:username, buffer: <<>>]

  @impl GenServer
  def handle_info({:broadcast, %Broadcast{} = message}, {socket, state}) do
    encoded_message = Protocol.encode_message(message)
    :ok = ThousandIsland.Socket.send(socket, encoded_message)
    {:noreply, {socket, state}}
  end

  @impl ThousandIsland.Handler
  def handle_connection(_socket, [] = _opts) do
    {:continue, %__MODULE__{}}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    state = update_in(state.buffer, &(&1 <> data))
    handle_new_state(state)
  end

  defp handle_new_state(state) do
    case Protocol.decode_message(state.buffer) do
      {:ok, message, rest} ->
        state = put_in(state.buffer, rest)

        case Connection.handle_message(message, state) do
          {:ok, state} ->
            handle_new_state(state)

          :error ->
            {:close, state}
        end

      :incomplete ->
        {:continue, state}

      :error ->
        Logger.error("Received invalid data, closing connection")
        {:close, state}
    end
  end
end
