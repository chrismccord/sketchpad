defmodule Sketchpad.Pad do
  use GenServer

  alias SketchpadWeb.PadChannel

  ## Client

  def png_ack(encoded_png, user_id) do
    with {:ok, decoded_png} <- Base.decode64(encoded_png),
         {:ok, path} <- Briefly.create(),
         {:ok, jpeg_path} <- Briefly.create(),
         :ok <- File.write(path, decoded_png),
         args = ["-background", "white", "-flatten", path, "jpg:" <> jpeg_path],
         {"", 0} <- System.cmd("convert", args),
         {ascii, 0} <- System.cmd("jp2a", ["-i", jpeg_path]) do

      IO.puts(ascii)
      IO.puts(">> #{user_id}")
      {:ok, ascii}
    else
      _ -> :error
    end
  end

  def find(pad_id) do
    case :global.whereis_name(topic(pad_id)) do
      pid when is_pid(pid) -> {:ok, pid}
      :undefined -> {:error, :noprocess}
    end
  end

  def put_stroke(pid, user_id, stroke) do
    GenServer.call(pid, {:put_stroke, user_id, stroke})
  end

  def clear(pid, user_id) do
    GenServer.call(pid, {:clear, user_id})
  end

  def render(pid, last_seen_id) do
    GenServer.call(pid, {:render, last_seen_id})
  end

  ## Server

  def start_link(pad_id) do
    GenServer.start_link(__MODULE__, [pad_id],
      name: {:global, topic(pad_id)})
  end

  defp schedule_png_request do
    Process.send_after(self(), :png_request, 3_000)
  end

  def init([pad_id]) do
    schedule_png_request()

    {:ok, %{pad_id: pad_id,
            users: [],
            topic: topic(pad_id)}}
  end

  alias SketchpadWeb.Endpoint

  def handle_info(:png_request, %{topic: topic} = state) do
    case SketchpadWeb.Presence.list(topic) do
      users when map_size(users) > 0 ->
        {user_id, %{metas: [first | _]}} = Enum.random(users)
        %{phx_ref: ref} = first
        Endpoint.broadcast!(topic <> ":#{ref}", "png_request", %{})

      _empty -> :noop
    end
    schedule_png_request()

    {:noreply, state}
  end

  def handle_call({:render, last_seen_id}, _from, state) do
    len = Enum.count(state.users)
    {:reply, Enum.slice(state.users, last_seen_id, len), state}
  end

  def handle_call({:clear, user_id}, _from, state) do
    PadChannel.broadcast_clear(state.topic, user_id)
    {:reply, :ok, %{state | users: []}}
  end

  def handle_call({:put_stroke, user_id, stroke}, _from, state) do
    PadChannel.broadcast_stroke(state.topic, user_id, stroke)
    {:reply, :ok, put_user_stroke(state, user_id, stroke)}
  end

  defp put_user_stroke(%{users: users} = state, user_id, stroke) do
    # users =
    #   users
    #   |> map.put_new_lazy(user_id, fn -> %{id: user_id, strokes: []} end)
    #   |> update_in([user_id, :strokes], fn strokes ->
    #     [stroke | strokes]
    #   end)

    %{state | users: users ++ [{user_id, stroke, Enum.count(users)}]}
  end

  defp topic(pad_id), do: "pad:#{pad_id}"
end
