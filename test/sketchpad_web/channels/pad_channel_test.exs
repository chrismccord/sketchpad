defmodule SketchpadWeb.PadChannelTest do
  use SketchpadWeb.ChannelCase
  alias SketchpadWeb.PadChannel

  setup do
    socket = Phoenix.Socket.assign(socket(), :user_id, "chrismccord")
    assert {:ok, %{msg: "welcome!"}, socket} =
      subscribe_and_join(socket, PadChannel, "pad:lobby", %{})
    {:ok, socket: socket}
  end

  test "clear event is broadcast to everyone but self", %{socket: socket} do
    ref = push socket, "clear", %{}
    assert_reply ref, :ok

    assert_broadcast "clear", %{}
  end

  test "messages include publishing user", %{socket: socket} do
    ref = push socket, "new_message", %{body: "hello!"}
    assert_reply ref, :ok
    assert_broadcast "new_message", %{
      body: "hello!",
      user_id: "chrismccord"
    }
  end
end
