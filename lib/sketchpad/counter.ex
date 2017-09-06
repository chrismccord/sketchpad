defmodule Counter do
  use GenServer

  ## Client

  def inc(pid), do: GenServer.cast(pid, :inc)

  def dec(pid), do: GenServer.cast(pid, :dec)

  def val(pid, timeout \\ 5000) do
    GenServer.call(pid, :val, timeout)
  end

  ## Server

  def start_link(initial_count \\ 0) do
    GenServer.start_link(__MODULE__, [initial_count], name: __MODULE__)
  end

  def init([initial_count]) do
    {:ok, initial_count, 5000}
  end

  def handle_cast(:inc, count) do
    {:noreply, count + 1}
  end

  def handle_cast(:dec, count) do
    {:noreply, count - 1}
  end

  def handle_call(:val, _from, count) do
    {:reply, count, count}
  end
end
