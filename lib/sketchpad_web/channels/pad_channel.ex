defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel

  def join("pad:" <> pad_id, _params, socket) do
    IO.puts ">> #{socket.assigns.user_id} joined pad #{pad_id}"
    {:ok, %{msg: "welcome!"}, assign(socket, :pad_id, pad_id)}
  end

  def handle_in("stroke", stroke, socket) do
    broadcast_from!(socket, "stroke", %{
      stroke: stroke,
      user_id: socket.assigns.user_id
    })

    {:reply, :ok, socket}
  end

  def handle_in("clear", _, socket) do
    broadcast_from!(socket, "clear", %{user_id: socket.assigns.user_id})
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
