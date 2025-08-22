defmodule Ip.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/myip" do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    IO.inspect(ip, label: "Client IP")
    response_body = JSON.encode!(%{ip: ip})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(200, response_body)
  end

  match _ do
    response_body = JSON.encode!(%{"errror" => "route not found"})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(404, response_body)
  end
end
