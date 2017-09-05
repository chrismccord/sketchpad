defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel

  alias Sketchpad.Pad

  ## Client

  ## Server
  def join("pad:" <> pad_id, params, socket) do
    {:ok, pid} = Pad.find(pad_id)
    IO.puts ">> #{socket.assigns.user_id} joined pad #{pad_id}"

    send(self(), {:after_join, params["lastSeenId"] || 0})

    socket =
      socket
      |> assign(:pad_id, pad_id)
      |> assign(:pad, pid)

    {:ok, %{msg: "welcome!"}, socket}
  end

  alias Phoenix.Socket.Broadcast

  def handle_info(%Broadcast{event: "png_request"}, socket) do
    push(socket, "png_request", %{})
    {:noreply, socket}
  end

  def handle_info({:after_join, last_seen_id}, socket) do
    %{pad: pad, user_id: user_id} = socket.assigns
    push(socket, "presence_state", SketchpadWeb.Presence.list(socket))
    {:ok, ref} = SketchpadWeb.Presence.track(socket, user_id, %{
      online_at: System.system_time()
    })
    :ok = SketchpadWeb.Endpoint.subscribe(socket.topic <> ":#{ref}")

    for {user_id, stroke, id} <- Pad.render(pad, last_seen_id) do
      push(socket, "stroke", %{id: id, user_id: user_id, stroke: stroke})
    end

    {:noreply, socket}
  end

  def broadcast_stroke(topic, user_id, stroke) do
    SketchpadWeb.Endpoint.broadcast!(topic, "stroke", %{
      stroke: stroke,
      user_id: user_id
    })
  end

  @png_prefix "data:image/png;base64,"
  def handle_in("png_ack", %{"png" => @png_prefix <> png}, socket) do
    {:ok, ascii} = Pad.png_ack(png, socket.assigns.user_id)
    {:reply, {:ok, %{ascii: ascii}}, socket}
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
