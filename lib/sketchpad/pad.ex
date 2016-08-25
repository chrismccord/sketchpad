defmodule Sketchpad.Pad do
  use GenServer

  ## Client

  def find(pad_id) do
    case :global.whereis_name("pad:#{pad_id}") do
      pid when is_pid(pid) -> {:ok, pid}
      :undefined -> {:error, :noprocess}
    end
  end

  def put_stroke(pid, pad_id, user_id, stroke) do
    :ok = GenServer.call(pid, {:stroke, user_id, stroke})
    Sketchpad.PadChannel.broadcast_stroke(pad_id, user_id, stroke)
  end

  def render(pid) do
    GenServer.call(pid, :render)
  end

  def clear(pid, pad_id) do
    :ok = GenServer.call(pid, :clear)
    Sketchpad.PadChannel.broadcast_clear(pad_id)
  end

  ## Server

  def start_link(pad_id) do
    GenServer.start_link(__MODULE__, [pad_id], name: {:global, "pad:#{pad_id}"})
  end

  def init(pad_id) do
    {:ok, %{users: %{}, pad_id: pad_id}}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | users: %{}}}
  end

  def handle_call({:stroke, user_id, stroke}, _from, state) do
    {:reply, :ok, put_user_stroke(state, user_id, stroke)}
  end

  def handle_call(:render, _from, state) do
    {:reply, state.users, state}
  end

  defp put_user_stroke(%{users: users} = state, user_id, stroke) do
    users = Map.put_new(users, user_id, %{id: user_id, strokes: []})
    users = update_in(users, [user_id, :strokes], fn strokes -> [stroke | strokes] end)

    %{state | users: users}
  end
end
