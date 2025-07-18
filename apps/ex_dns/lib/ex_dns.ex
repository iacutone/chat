# ---
# Excerpted from "Network Programming in Elixir and Erlang",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/alnpee for more book information.
# ---
defmodule ExDns do
  defp encode_dns_message(message_id, record_type, hostname) do
    header = %ExDns.Protocol.Header{
      message_id: message_id,
      qr: 0,
      opcode: 0,
      rcode: 0,
      aa: 0,
      tc: 0,
      rd: 1,
      ra: 0,
      an_count: 0,
      ns_count: 0,
      ar_count: 0,
      qd_count: 1
    }

    question = %ExDns.Protocol.Question{
      qname: hostname,
      qtype: record_type,
      qclass: 1
    }

    [
      ExDns.Protocol.encode_header(header),
      ExDns.Protocol.encode_question(question)
    ]
  end

  defp decode_dns_message(
         message_id,
         <<header::12-binary, rest::binary>> = whole_response
       ) do
    %ExDns.Protocol.Header{
      qr: 1,
      message_id: ^message_id,
      opcode: 0,
      rcode: 0,
      qd_count: 1,
      an_count: answer_count
    } = ExDns.Protocol.decode_header(header)

    {_question, rest} = ExDns.Protocol.decode_question(rest)

    {answers, rest} =
      Enum.map_reduce(1..answer_count, rest, fn _index, rest ->
        ExDns.Protocol.decode_answer(whole_response, rest)
      end)

    if rest != "" do
      raise "unexpected trailing data in DNS message"
    end

    answers
  end
end
