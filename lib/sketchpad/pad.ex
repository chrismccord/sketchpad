defmodule Sketchpad.Pad do
  use GenServer

  def clear(pad_id) do
    pad_id
    |> find!()
    |> GenServer.call(:clear)
  end

  def render(pad_id) do
    pad_id
    |> find!()
    |> GenServer.call(:render)
  end

  def put_stroke(pad_id, user_id, stroke, publisher) do
    pad_id
    |> find!()
    |> GenServer.call({:put_stroke, user_id, stroke, publisher})
  end

  def find!(pad_id) do
    case Registry.lookup(Sketchpad.Registry, pad_id) do
      [{pid, _}] ->
        pid

      [] ->
        raise ArgumentError,
              "No process found for pad_id #{inspect(pad_id)}"
    end
  end

  def start_link(opts) do
    pad_id = Keyword.fetch!(opts, :pad_id)

    GenServer.start_link(__MODULE__, [pad_id],
      name: {:via, Registry, {Sketchpad.Registry, pad_id}}
    )
  end

  def init([pad_id]) do
    state = %{
      pad_id: pad_id,
      users: %{}
    }

    {:ok, state}
  end

  def handle_call(:render, _from, state) do
    {:reply, state.users, state}
  end

  def handle_call(:clear, _from, state) do
    SketchpadWeb.PadChannel.broadcast_clear(state.pad_id)
    {:reply, :ok, %{state | users: %{}}}
  end

  def handle_call({:put_stroke, user_id, stroke, publisher}, _from, state) do
    SketchpadWeb.PadChannel.broadcast_stroke_from(
      publisher,
      state.pad_id,
      user_id,
      stroke
    )

    {:reply, :ok, put_user_stroke(state, user_id, stroke)}
  end

  defp put_user_stroke(%{users: users} = state, user_id, stroke) do
    users =
      users
      |> Map.put_new_lazy(user_id, fn -> %{id: user_id, strokes: []} end)
      |> update_in([user_id, :strokes], fn strokes -> [stroke | strokes] end)

    %{state | users: users}
  end
end
