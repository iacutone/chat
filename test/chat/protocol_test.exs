defmodule Chat.ProtocolTest do
  use ExUnit.Case, async: true

  alias Chat.Message.Broadcast
  alias Chat.Message.Register
  alias Chat.Protocol

  describe "decode_message/1" do
    test "can decode register messages" do
      binary = <<0x01, 0x00, 0x03, "meg", "rest">>
      assert {:ok, message, rest} = Chat.Protocol.decode_message(binary)
      assert message == %Register{username: "meg"}
      assert rest == "rest"

      assert Protocol.decode_message(<<0x01, 0x00>>) == :incomplete
    end

    test "can decode broadcast messages" do
      binary = <<0x02, 3::16, "meg", 2::16, "hi", "rest">>
      assert {:ok, message, rest} = Chat.Protocol.decode_message(binary)
      assert message == %Broadcast{from_username: "meg", contents: "hi"}
      assert rest == "rest"

      assert Protocol.decode_message(<<0x02, 0x00>>) == :incomplete
    end

    test "returns :incomplete for empty data" do
      assert Protocol.decode_message(<<>>) == :incomplete
      assert Protocol.decode_message("") == :incomplete
    end

    test "returns :error for uknown message types" do
      assert :error = Protocol.decode_message(<<0x03, "rest">>)
    end
  end

  describe "encode_message/1" do
    test "can encode register messages" do
      message = %Register{username: "meg"}
      iodata = Protocol.encode_message(message)
      assert IO.iodata_to_binary(iodata) == <<0x01, 0x00, 0x03, "meg">>
    end

    test "can encode broadcast messages" do
      message = %Broadcast{from_username: "meg", contents: "hi"}
      iodata = Protocol.encode_message(message)

      assert <<0x02, 0x00, 0x03, "meg", 0x00, 0x02, "hi">> = IO.iodata_to_binary(iodata)
    end
  end
end
