defmodule Counter do
  use GenServer

  def inc(pid), do: GenServer.cast(pid, :inc)
  def dec(pid), do: GenServer.cast(pid, :dec)

  def val(pid) do
    GenServer.call(pid, :val)
  end

  def start_link(initial_count \\ 0) do
    GenServer.start_link(__MODULE__, [initial_count], name: __MODULE__)
  end

  def init([initial_count]) do
    {:ok, initial_count}
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

  def handle_info(:tick, count) do
    val = count + 1
    if val == 5, do: raise("reached 5")
    {:noreply, IO.inspect(val)}
  end
end
