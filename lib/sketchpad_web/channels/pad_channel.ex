defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel


  def join("pad:" <> pad_id, _params, socket) do
    IO.puts ">> #{socket.assigns.user_id} joined pad #{pad_id}"
    :timer.send_interval(2000, self(), :tick)
    {:ok, %{msg: "welcome!"}, assign(socket, :pad_id, pad_id)}
  end

  def handle_info(:tick, socket) do
    push socket, "tick", %{system_time: System.system_time()}
    {:noreply, socket}
  end
end
