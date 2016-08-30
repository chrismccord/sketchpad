defmodule Sketchpad.Pad do
  use GenServer
  alias Sketchpad.{PadChannel}

  ## Client

  def find(pad_id) do
    case :global.whereis_name("pad:#{pad_id}") do
      pid when is_pid(pid) -> {:ok, pid}
      :undefined -> {:error, :noprocess}
    end
  end

  def put_stroke(from, pid, pad_id, user_id, stroke) do
    :ok = GenServer.call(pid, {:stroke, user_id, stroke})
    PadChannel.broadcast_stroke_from(from, pad_id, user_id, stroke)
  end

  def render(pid) do
    GenServer.call(pid, :render)
  end

  def clear(pid, pad_id) do
    :ok = GenServer.call(pid, :clear)
    PadChannel.broadcast_clear(pad_id)
  end

  def png_ack(user_id, encoded_img) do
    with {:ok, decoded_img} <- Base.decode64(encoded_img),
         {:ok, path} <- Briefly.create(),
         {:ok, jpg_path} <- Briefly.create(),
         :ok <- File.write(path, decoded_img),
         args = ["-background", "white", "-flatten", path, "jpg:" <> jpg_path],
         {"", 0} <- System.cmd("convert", args),
         {ascii, 0} = System.cmd("jp2a", ["-i", jpg_path]) do

      IO.puts(ascii)
      IO.puts(">>" <> user_id)
      {:ok, ascii}
    else
      _ -> :error
    end
  end

  ## Server

  def start_link(pad_id) do
    GenServer.start_link(__MODULE__, [pad_id], name: {:global, "pad:#{pad_id}"})
  end

  def init(pad_id) do
    Process.send_after(self(), :request_pad_png, 3_000)
    {:ok, %{users: %{}, pad_id: pad_id}}
  end

  def handle_info(:request_pad_png, %{pad_id: pad_id} = state) do
    case Sketchpad.Presence.list("pad:#{pad_id}") do
      users when map_size(users) > 0 ->
        {_user_id, %{metas: [%{phx_ref: ref} | _]}} = Enum.random(users)
        Sketchpad.Endpoint.broadcast("pad:#{pad_id}:#{ref}", "pad_request", %{pad_id: pad_id})
      _ -> :noop
    end
    Process.send_after(self(), :request_pad_png, 3_000)
    {:noreply, state}
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
