defmodule Mix.Tasks.ChatClient do
  use Mix.Task
  import Chat.Protocol
  alias Chat.Message.{Broadcast, Register}

  def run([] = _) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary, active: :once])

    user = Mix.shell().prompt("Enter your username: ") |> String.trim()

    :ok = :gen_tcp.send(socket, encode_message(%Register{username: user}))

    receive_loop(user, socket, spawn_user_task(user))
  end

  defp spawn_user_task(user) do
    Task.async(fn -> Mix.shell().prompt("#{user}> ") end)
  end

  defp receive_loop(user, socket, %Task{ref: ref} = prompt_task) do
    receive do
      {^ref, message} ->
        broadcast = %Broadcast{from_username: user, contents: message}
        :ok = :gen_tcp.send(socket, encode_message(broadcast))
        receive_loop(user, socket, spawn_user_task(user))

      {:DOWN, ^ref, _, _, _} ->
        Mix.raise("Prompt task died")

      {:tcp, ^socket, data} ->
        :ok = :inet.setopts(socket, active: :once)
        handle_data(data)
        receive_loop(user, socket, prompt_task)

      {:tcp_closed, ^socket} ->
        IO.puts("Connection closed")

      {:tcp_error, ^socket, reason} ->
        Mix.raise("TCP error: #{inspect(reason)}")
    end
  end

  defp handle_data(data) do
    case decode_message(data) do
      {:ok, %Broadcast{} = message, ""} ->
        IO.puts("\n#{message.from_username}> #{message.contents}")

      _ ->
        Mix.raise("Invalid message: #{inspect(data)}")
    end
  end
end
