defmodule Counter do
  use GenServer
  def inc(pid), do: GenServer.cast(pid, :inc)
  def dec(pid), do: GenServer.cast(pid, :dec)

  def val(pid, timeout \\ 5000) do
    GenServer.call(pid, :val, timeout)
  end

  def start_link(initial_count \\ 0) do
    GenServer.start_link(__MODULE__, [initial_count], name: __MODULE__)
  end

  def init([initial_count]) do
    {:ok, initial_count}
  end

  def handle_cast(:inc, count), do: {:noreply, count + 1}
  def handle_cast(:dec, count), do: {:noreply, count - 1}

  def handle_call(:val, _from, count) do
    {:reply, count, count}
  end

  def handle_info(:tick, count) do
    count = count + 1
    if count > 5, do: raise("boom")
    {:noreply, IO.inspect(count)}
  end
end
