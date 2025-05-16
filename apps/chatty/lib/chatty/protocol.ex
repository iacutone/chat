defmodule Chatty.Protocol do
  alias Chatty.Message.Broadcast
  alias Chatty.Message.Register

  def decode_message(<<0x01, rest::binary>>) do
    decode_register(rest)
  end

  def decode_message(<<0x02, rest::binary>>) do
    decode_broadcast(rest)
  end

  def decode_message(<<>>), do: :incomplete

  def decode_message(<<_::binary>>), do: :error

  def encode_message(message)

  def encode_message(%Register{username: username}) do
    [0x01, encode_string(username)]
  end

  def encode_message(%Broadcast{from_username: username, contents: contents}) do
    [0x02, encode_string(username), encode_string(contents)]
  end

  def encode_string(str) do
    [<<byte_size(str)::16>>, str]
  end

  defp decode_register(<<username_len::16, username::size(username_len)-binary, rest::binary>>) do
    {:ok, %Register{username: username}, rest}
  end

  defp decode_register(<<_::binary>>), do: :incomplete

  defp decode_broadcast(
         <<username_len::16, username::size(username_len)-binary, contents_len::16,
           contents::size(contents_len)-binary, rest::binary>>
       ) do
    {:ok, %Broadcast{from_username: username, contents: contents}, rest}
  end

  defp decode_broadcast(<<_::binary>>), do: :incomplete
end
