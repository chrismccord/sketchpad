defmodule Sketchpad.Web.PadChannel do
  use Sketchpad.Web, :channel
  alias Sketchpad.{Pad, Web.Presence}
  alias Phoenix.Socket.Broadcast

  def broadcast_stroke_from(from, pad_id, user_id, stroke) do
    Sketchpad.Web.Endpoint.broadcast_from!(from, "pad:#{pad_id}", "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def broadcast_clear(pad_id) do
    Sketchpad.Web.Endpoint.broadcast!("pad:#{pad_id}", "clear", %{})
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

  def handle_info(%Broadcast{event: "pad_request"}, socket) do
    push socket, "pad_request", %{}
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    push socket, "presence_state", Presence.list(socket)
    {:ok, ref} = Presence.track(socket, socket.assigns.user_id, %{})
    :ok = Sketchpad.Web.Endpoint.subscribe("pad:#{socket.assigns.pad_id}:#{ref}")

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
    :ok = Pad.put_stroke(self(), pad, pad_id, user_id, stroke)

    {:reply, :ok, socket}
  end

  def handle_in("publish_msg", %{"body" => body}, socket) do
    broadcast!(socket, "new_msg", %{body: body, user_id: socket.assigns.user_id})

    {:reply, :ok, socket}
  end

  def handle_in("pad_png", %{"img" => "data:image/png;base64," <> img}, socket) do
    {:ok, _ascii} = Pad.png_ack(socket.assigns.user_id, img)
    {:noreply, socket}
  end
end
