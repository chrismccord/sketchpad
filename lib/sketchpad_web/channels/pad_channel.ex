defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel
  alias Sketchpad.Pad
  alias SketchpadWeb.Presence

  def join("pad:" <> pad_id, _params, socket) do
    send(self(), :after_join)
    {:ok, %{users: "welcome!"}, assign(socket, :pad_id, pad_id)}
  end

  def handle_info(:png_request, socket) do
    push(socket, "png_request", %{})
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:ok, ref} = Presence.track(socket, socket.assigns.user_id, %{})
    socket.endpoint.subscribe(socket.topic <> ":#{ref}")

    for {user_id, %{strokes: strokes}} <- Pad.render(socket.assigns.pad_id) do
      for stroke <- Enum.reverse(strokes) do
        push(socket, "stroke", %{user_id: user_id, stroke: stroke})
      end
    end

    {:noreply, socket}
  end

  def handle_in("stroke", stroke, socket) do
    %{user_id: user_id, pad_id: pad_id} = socket.assigns
    :ok = Pad.put_stroke(pad_id, user_id, stroke, self())
    {:reply, :ok, socket}
  end

  def handle_in("clear", _, socket) do
    Pad.clear(socket.assigns.pad_id)

    {:reply, :ok, socket}
  end

  def handle_in("new_message", %{"body" => body}, socket) do
    broadcast!(socket, "new_message", %{
      user_id: socket.assigns.user_id,
      body: body
    })
    {:reply, :ok, socket}
  end


  @png_prefix "data:image/png;base64,"
  def handle_in("png_ack", %{"img" => @png_prefix <> img}, socket) do
    {:ok, ascii} = Pad.png_ack(img)

    IO.puts(ascii)
    IO.puts(">> #{socket.assigns.user_id}")

    {:reply, {:ok, %{ascii: ascii}}, socket}
  end
end
