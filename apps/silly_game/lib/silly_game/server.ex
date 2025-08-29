defmodule SillyGame.Server do
  @behaviour :websock

  defstruct [:phase, :timer_ref]

  require Logger

  @impl WebSock
  def init(_opts) do
    Logger.info("Started WebSocket connection handler")
    state = schedule_next_tick(%__MODULE__{})
    {:ok, state}
  end

  def handle_info(:tick, %__MODULE__{phase: :idle} = state) do
    Logger.info("Ticked! Client has 1 second to respond")
    timer_ref = Process.send_after(self(), :tick_expired, 1000)
    state = %{state | phase: :ticked, timer_ref: timer_ref}
    {:push, {:text, "ping"}, state}
  end

  def handle_info(:tick_expired, %__MODULE__{phase: :ticked} = state) do
    Logger.info("Tick expired! Client didn't respond in time")
    state = schedule_next_tick(%{state | timer_ref: nil})
    {:push, {:text, "expired"}, state}
  end

  def handle_in(
        {"pong", [opcode: :text]},
        %__MODULE__{phase: :ticked} = state
      ) do
    Logger.info("Client responded in time! You won!")

    state =
      state
      |> cancel_expiration_timer()
      |> schedule_next_tick()

    {:push, {:text, "won"}, state}
  end

  def handle_in(
        {"pong", [opcode: :text]},
        %__MODULE__{phase: :idle} = state
      ) do
    Logger.info("Client responded without being asked")
    {:push, {:text, "early"}, state}
  end

  defp cancel_expiration_timer(%__MODULE__{} = state) do
    case Process.cancel_timer(state.timer_ref) do
      time_left when is_integer(time_left) ->
        :ok

      false ->
        # Flush
        receive do
          :tick_expired -> :ok
        after
          0 -> :ok
        end
    end

    %__MODULE__{state | timer_ref: nil}
  end

  defp schedule_next_tick(state) do
    timeout = Enum.random(5_000..10_000)
    Process.send_after(self(), :tick, timeout)
    Logger.info("Scheduled next tick in #{timeout}ms")
    %{state | phase: :idle}
  end
end
