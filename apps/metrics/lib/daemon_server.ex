defmodule Metrics.DaemonServer do
  use GenServer

  defstruct socket: nil, metrics: %{}, flush_io_device: nil

  @flush_interval_millisec :timer.seconds(15)

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    port = Keyword.fetch!(options, :port)
    flush_io_device = Keyword.get(options, :flush_io_device, :stdio)

    case :gen_udp.open(port, [:binary, active: true]) do
      {:ok, socket} ->
        :timer.send_interval(@flush_interval_millisec, self(), :flush)
        {:ok, %__MODULE__{socket: socket, flush_io_device: flush_io_device}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_info({:udp, socket, _ip, _port, data}, %{socket: socket} = state) do
    {metrics, _errors} = Metrics.Protocol.parse_metrics(data)
    state = Enum.reduce(metrics, state, &process_metric/2)
    {:noreply, state}
  end

  def process_metric({:gauge, name, value}, state) do
    put_in(state.metrics[name], {:gauge, value})
  end

  def process_metric({:counter, name, value}, state) do
    case state.metrics[name] || {:counter, 0} do
      {counter, current} ->
        put_in(state.metrics[name], {counter, current + value})

      _other ->
        state
    end
  end

  def handle_info(:flush, state) do
    IO.puts(state.flush_io_device, """
    ===============
    Current metrics
    ===============
    """)

    state =
      update_in(state.metrics, fn metrics ->
        Map.new(metrics, fn
          {name, {:counter, value}} ->
            IO.puts(state.flush_io_device, "#{name}:\t#{value}")
            {name, {:counter, 0}}

          {name, {:gauge, value}} ->
            IO.puts(state.flush_io_device, "#{name}:\t#{value}")
            {name, {:gauge, value}}
        end)
      end)

    IO.puts(state.flush_io_device, "\n\n\n")

    {:noreply, state}
  end
end
