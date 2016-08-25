defmodule Sketchpad.PadChannel do
  use Sketchpad.Web, :channel
  alias Sketchpad.{Pad, Presence}

  def broadcast_stroke(pad_id, user_id, stroke) do
    Sketchpad.Endpoint.broadcast!("pad:#{pad_id}", "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def broadcast_clear(pad_id) do
    Sketchpad.Endpoint.broadcast!("pad:#{pad_id}", "clear", %{})
  end

  def join("pad:" <> id, _params, socket) do
    {:ok, pad} = Pad.find(id)
    socket =
      socket
      |> assign(:pad, pad)
      |> assign(:pad_id, id)

    send self(), :after_join

    {:ok, %{user_id: socket.assigns.user_id, data: %{}}, socket}
  end

  def handle_info(:after_join, socket) do
    push socket, "presence_state", Presence.list(socket)
    {:ok, _ref} = Presence.track(socket, socket.assigns.user_id, %{})

    for item <- Pad.render(socket.assigns.pad), {user_id, %{strokes: strokes}} = item do
      for stroke <- Enum.reverse(strokes) do
        push socket, "stroke", %{user_id: user_id, stroke: stroke}
      end
    end
    {:noreply, socket}
  end

  def handle_in("clear", _, socket) do
    :ok = Pad.clear(socket.assigns.pad, socket.assigns.pad_id)
    {:reply, :ok, socket}
  end

  def handle_in("stroke", stroke, socket) do
    %{user_id: user_id, pad_id: pad_id, pad: pad} = socket.assigns
    :ok = Pad.put_stroke(pad, pad_id, user_id, stroke)

    {:reply, :ok, socket}
  end

  def handle_in("publish_msg", %{"body" => body}, socket) do
    broadcast!(socket, "new_msg", %{body: body, user_id: socket.assigns.user_id})

    {:reply, :ok, socket}
  end


  def handle_in("ocr", %{"img" => "data:image/png;base64," <> img}, socket) do
    {:ok, path} = Briefly.create()
    {:ok, jpg_path} = Briefly.create()
    File.write!(path, Base.decode64!(img))
    {"", 0} = System.cmd("convert", ["-background", "white", "-flatten", path, "jpg:" <> jpg_path])
    {ascii, 0} = System.cmd("jp2a", ["-i", jpg_path])
    # IO.puts ascii
    # {txt, _} = System.cmd("tesseract", [path, "stdout", "-l eng"])
    # IO.inspect txt
    # broadcast!(socket, "ocr", %{text: txt})

    {:reply, :ok, socket}
  end
end
