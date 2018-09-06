defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel
  alias Sketchpad.Pad

  def topic(pad_id), do: "pad:#{pad_id}"

  def broadcast_stroke_from(from, pad_id, user_id, stroke) do
    SketchpadWeb.Endpoint.broadcast_from!(from, topic(pad_id), "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def join("pad:" <> pad_id, _params, socket) do
    send(self(), :after_join)

    socket =
      socket
      |> assign(:pad_id, pad_id)

    {:ok, socket}
  end

  def broadcast_clear(pad_id) do
    pad_id
    |> topic()
    |> SketchpadWeb.Endpoint.broadcast!("clear", %{})
  end

  def handle_in("stroke", data, socket) do
    %{user_id: user_id, pad_id: pad_id} = socket.assigns
    # broadcast_stroke_from(self(), pad_id, user_id, data)
    Pad.put_stroke(pad_id, user_id, data, self())
    {:reply, :ok, socket}
  end

  def handle_in("clear", _, socket) do
    # broadcast_clear(socket.assigns.pad_id)
    Pad.clear(socket.assigns.pad_id)
    {:reply, :ok, socket}
  end

  def handle_in("new_message", %{"body" => body}, socket) do
    broadcast!(socket, "new_message", %{
      user_id: socket.assigns.user_id,
      body: body
    })

    {:reply, {:ok, %{hello: "world"}}, socket}
  end

  @png_prefix "data:image/png;base64,"
  def handle_in("png_ack", %{"png" => @png_prefix <> encoded_png}, socket) do
    {:ok, ascii} = Pad.png_ack(encoded_png)

    IO.puts(ascii)
    IO.puts(">> #{socket.assigns.user_id}")

    {:reply, {:ok, %{ascii: ascii}}, socket}
  end

  alias SketchpadWeb.Presence
  def handle_info(:request_png, socket) do
    push(socket, "request_png", %{})

    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:ok, ref} = Presence.track(socket, socket.assigns.user_id, %{
      device: "Mobile"
    })
    socket.endpoint.subscribe("pad_users:#{ref}")

    for {user_id, %{strokes: strokes}} <- Pad.render(socket.assigns.pad_id) do
      for stroke <- Enum.reverse(strokes) do
        push(socket, "stroke", %{user_id: user_id, stroke: stroke})
      end
    end

    {:noreply, socket}
  end
end
