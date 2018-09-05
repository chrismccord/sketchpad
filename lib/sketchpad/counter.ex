defmodule Counter do
  def inc(pid), do: send(pid, :inc)
  def dec(pid), do: send(pid, :dec)

  def val(pid, timeout \\ 5000) do
    ref = Kernel.make_ref()
    send(pid, {:val, self(), ref})

    receive do
      {:val, value, ^ref} ->
        value
    after
      timeout -> exit(:timeout)
    end
  end

  def start_link(initial_count \\ 0) do
    {:ok, spawn_link(__MODULE__, :init, [initial_count])}
  end

  def init(initial_count) do
    :timer.send_interval(1000, self(), :tick)
    run(initial_count)
  end

  defp run(count) do
    receive do
      message ->
        message
        |> handle_in(count)
        |> run()
    end
  end

  def handle_in(:inc, count), do: count + 1
  def handle_in(:dec, count), do: count - 1

  def handle_in({:val, caller, ref}, count) do
    send(caller, {:val, count, ref})
    count
  end

  def handle_in(:tick, count) do
    count = count + 1
    if count > 5, do: raise("boom")
    IO.inspect(count)
  end
end
