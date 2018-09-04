defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel

  def broadcast_stroke_from(pid, pad_id, user_id, stroke) do
    SketchpadWeb.Endpoint.broadcast_from!(pid, "pad:#{pad_id}", "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def join("pad:" <> pad_id, _params, socket) do
    socket =
      socket
      |> assign(:pad_id, pad_id)

    {:ok, socket}
  end

  def handle_in("stroke", stroke, socket) do
    %{pad_id: pad_id, user_id: user_id} = socket.assigns
    broadcast_stroke_from(self(), pad_id, user_id, stroke)

    {:reply, :ok, socket}
  end

  def broadcast_clear(pad_id) do
    SketchpadWeb.Endpoint.broadcast!("pad:#{pad_id}", "clear", %{})
  end

  def handle_in("clear", _, socket) do
    broadcast_clear(socket.assigns.pad_id)
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
