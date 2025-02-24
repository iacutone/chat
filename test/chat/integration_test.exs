defmodule Chat.IntegrationTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Chat.Message.Broadcast
  alias Chat.Message.Register
  alias Chat.Protocol

  test "server closes connection if the client sends register message twice" do
    {:ok, client} = :gen_tcp.connect(~c"localhost", 4000, [:binary])
    encoded_message = Protocol.encode_message(%Register{username: "jd"})
    :ok = :gen_tcp.send(client, encoded_message)

    log =
      capture_log(fn ->
        :ok = :gen_tcp.send(client, encoded_message)
        assert_receive {:tcp_closed, ^client}, 500
      end)

    assert log =~ "Invalid Register message, had already recceived one"
  end

  test "broadcasting messages" do
    client_jd = connect_user("jd")
    client_amy = connect_user("amy")

    Process.sleep(100)

    broadcast_message = %Broadcast{from_username: "", contents: "Hello, world!"}
    encoded_message = Protocol.encode_message(broadcast_message)
    :ok = :gen_tcp.send(client_amy, encoded_message)

    refute_receive {:tcp, ^client_amy, _data}

    assert_receive {:tcp, ^client_jd, data}, 500
    assert {:ok, msg, ""} = Protocol.decode_message(data)
    assert ^msg = %Broadcast{from_username: "amy", contents: "Hello, world!"}
  end

  def connect_user(username) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary])
    register_message = %Register{username: username}
    encoded_message = Protocol.encode_message(register_message)
    :ok = :gen_tcp.send(socket, encoded_message)
    socket
  end
end
