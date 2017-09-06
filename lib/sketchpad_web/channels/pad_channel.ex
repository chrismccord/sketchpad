defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel

  def join("pad:" <> pad_id, _params, socket) do
    {:ok, %{msg: "welcome!"}, socket}
  end

  def handle_in("stroke", data, socket) do
    broadcast_from!(socket, "stroke", %{
      user_id: socket.assigns.user_id,
      stroke: data
    })

    {:reply, :ok, socket}
  end

  def handle_in("clear", _, socket) do
    broadcast!(socket, "clear", %{})
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
