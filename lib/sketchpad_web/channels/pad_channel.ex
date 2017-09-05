defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel

  alias Sketchpad.Pad

  ## Client

  ## Server
  def join("pad:" <> pad_id, _params, socket) do
    {:ok, pid} = Pad.find(pad_id)
    IO.puts ">> #{socket.assigns.user_id} joined pad #{pad_id}"

    send(self(), :after_join)

    socket =
      socket
      |> assign(:pad_id, pad_id)
      |> assign(:pad, pid)

    {:ok, %{msg: "welcome!"}, socket}
  end

  def handle_info(:after_join, socket) do
    pad = socket.assigns.pad

    for {user_id, %{strokes: strokes}} <- Pad.render(pad) do
      for stroke <- Enum.reverse(strokes) do
        push(socket, "stroke", %{user_id: user_id, stroke: stroke})
      end
    end

    {:noreply, socket}
  end

  def broadcast_stroke(topic, user_id, stroke) do
    SketchpadWeb.Endpoint.broadcast!(topic, "stroke", %{
      stroke: stroke,
      user_id: user_id
    })
  end

  def handle_in("stroke", stroke, socket) do
    Pad.put_stroke(
      socket.assigns.pad,
      socket.assigns.user_id,
      stroke
    )
    {:reply, :ok, socket}
  end

  def broadcast_clear(topic, user_id) do
    SketchpadWeb.Endpoint.broadcast!(topic, "clear", %{
      user_id: user_id
    })
  end

  def handle_in("clear", _, socket) do
    Pad.clear(socket.assigns.pad, socket.assigns.user_id)
    {:reply, :ok, socket}
  end


  def handle_in("new_message", %{"body" => body}, socket) do
    broadcast!(socket, "new_message", %{
      user_id: socket.assigns.user_id,
      body: body
    })

    {:reply, :ok, socket}
  end
end
