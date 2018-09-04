defmodule Sketchpad.Pad do
  use GenServer

  def png_ack(encoded_png) do
    with {:ok, decoded_png} <- Base.decode64(encoded_png),
         {:ok, path} <- Briefly.create(),
         {:ok, jpeg_path} <- Briefly.create(),
         :ok <- File.write(path, decoded_png),
         args = ["-background", "white", "-flatten", path, "jpg:" <> jpeg_path],
         {_, 0} <- System.cmd("convert", args),
         {ascii, _} <- System.cmd("jp2a", ["-i", jpeg_path]) do

      {:ok, ascii}
    else
      reason -> {:error, reason}
    end
  end

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

  def stroke(pad_id, user_id, stroke, publisher) do
    pad_id
    |> find!()
    |> GenServer.call({:put_stroke, user_id, stroke, publisher})
  end

  def find!(pad_id) do
    case Registry.lookup(Sketchpad.Registry, topic(pad_id)) do
      [{pid, _}] -> pid
      [] -> raise ArgumentError, "no process found for pad id #{inspect(pad_id)}"
    end
  end

  def start_link(opts) do
    pad_id = Keyword.fetch!(opts, :pad_id)

    GenServer.start_link(__MODULE__, [pad_id],
      name: {:via, Registry, {Sketchpad.Registry, topic(pad_id)}}
    )
  end

  def init([pad_id]) do
    schedule_png_request()
    state = %{
      pad_id: pad_id,
      topic: topic(pad_id),
      users: %{}
    }

    {:ok, state}
  end

  defp schedule_png_request do
    Process.send_after(self(), :request_png, 3000)
  end

  def handle_info(:request_png, state) do
    case SketchpadWeb.Presence.list(state.topic) do
      users when map_size(users) > 0 ->
        priv_topic = find_random_user_topic(users, state.topic)
        Phoenix.PubSub.broadcast(Sketchpad.PubSub, priv_topic, :png_request)

      _ -> :noop
    end
    schedule_png_request()
    {:noreply, state}
  end
  defp find_random_user_topic(users, topic) do
    {_user_id, %{metas: metas}} = Enum.random(users)
    [%{phx_ref: ref} | _] = metas

    topic <> ":#{ref}"
  end

  defp topic(pad_id), do: "pad:#{pad_id}"

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
