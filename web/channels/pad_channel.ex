defmodule Sketchpad.PadChannel do
  use Sketchpad.Web, :channel

  def join("pad:" <> _id, _params, socket) do
    {:ok, socket}
  end

  def handle_in("stroke", stroke, socket) do
    broadcast_from!(socket, "stroke", stroke)
    {:reply, :ok, socket}
  end

  def handle_in("ocr", %{"img" => "data:image/png;base64," <> img}, socket) do
    {:ok, path} = Briefly.create()
    {:ok, jpg_path} = Briefly.create()
    File.write!(path, Base.decode64!(img))
    {"", 0} = System.cmd("convert", ["-background", "white", "-flatten", path, "jpg:" <> jpg_path])
    {ascii, 0} = System.cmd("jp2a", ["-i", jpg_path])
    IO.puts ascii
    # {txt, _} = System.cmd("tesseract", [path, "stdout", "-l eng"])
    # IO.inspect txt
    # broadcast!(socket, "ocr", %{text: txt})

    {:reply, :ok, socket}
  end
end
