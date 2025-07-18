defmodule ExDns.Server do
  use GenServer

  require Logger

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def store(qname, qtype, rdata) do
    GenServer.call(__MODULE__, {:store, qname, qtype, rdata})
  end

  @impl true
  def init(options) do
    table = :ets.new(__MODULE__, [:bag, :named_table])
    port = Keyword.get(options, :port, 0)
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])

    {:ok, actual_port} = :inet.port(socket)

    Logger.info("DNS server started on port #{actual_port}")

    {:ok, %{socket: socket, table: table}}
  end

  @impl true
  def handle_call({:store, qname, qtype, rdata}, _from, %{table: table} = state) do
    :ets.insert(table, {{qname, qtype}, rdata})

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(
        {:udp, socket, ip, port, <<header::12-binary, body::binary>>},
        %{socket: socket} = state
      ) do
    Logger.info("Received DNS request from #{:inet.ntoa(ip)}:#{port}")

    header = ExDns.Protocol.decode_header(header)
    {questions, _rest} = decode_questions(header, body)
    answers = Enum.flat_map(questions, &fetch_answers(state.table, &1))

    reply_header = %ExDns.Protocol.Header{
      message_id: header.message_id,
      qr: 1,
      opcode: 0,
      rcode: 0,
      an_count: length(answers)
    }

    reply = [
      ExDns.Protocol.encode_header(reply_header),
      Enum.map(answers, &ExDns.Protocol.encode_answer/1)
    ]

    :ok = :gen_udp.send(socket, ip, port, reply)
    {:noreply, state}
  end

  defp decode_questions(header, body) do
    Enum.map_reduce(1..header.qd_count//1, body, fn _index, rest ->
      ExDns.Protocol.decode_question(rest)
    end)
  end

  defp fetch_answers(table, question) do
    case :ets.lookup(table, {question.qname, question.qtype}) do
      [] ->
        []

      records ->
        Enum.map(records, fn {_key, rdata} ->
          %ExDns.Protocol.Answer{
            name: question.qname,
            type: question.qtype,
            class: question.qclass,
            ttl: 300,
            rdata: rdata
          }
        end)
    end
  end
end
