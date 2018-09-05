defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel

  def join("pad:" <> pad_id, _params, socket) do
    :timer.send_interval(1000, self(), :count)

    socket =
      socket
      |> assign(:pad_id, pad_id)
      |> assign(:count, 0)

    {:ok, socket}
  end

  def handle_info(:count, socket) do
    if socket.assigns.count > 5, do: raise "boom"
    push(socket, "tick", %{value: socket.assigns.count})
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end
end
