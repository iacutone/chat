defmodule Metrics.Reporter do
  use GenServer

  require Logger

  @mtu 512

  defstruct [:socket, :dest_port]

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def increment_counter(server, name, value) do
    GenServer.cast(server, {:send_metric, {:counter, name, value}})
  end

  def set_gauge(server, name, value) do
    GenServer.cast(server, {:send_metric, {:gauge, name, value}})
  end

  @impl true
  def init(options) do
    dest_port = Keyword.fetch!(options, :dest_port)

    case :gen_udp.open(0, [:binary]) do
      {:ok, socket} ->
        state = %__MODULE__{socket: socket, dest_port: dest_port}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:send_metric, metric}, %__MODULE__{} = state) do
    iodata = Metrics.Protocol.encode_metric(metric)

    # guarantee that the metric is not larger than the MTU
    # UDP packets larger than the MTU are dropped
    # so we don't send metrics that don't fit into a single UDP packet
    # the daemon won't be able to construct metrics based on incomplete
    # packet data
    if IO.iodata_length(iodata) > @mtu do
      Logger.error("Metric too large to send: #{inspect(metric)}")
    else
      _ = :gen_udp.send(state.socket, ~c"localhost", state.dest_port, iodata)
    end

    {:noreply, state}
  end
end
