defmodule SketchpadWeb.PadChannelTest do
  use SketchpadWeb.ChannelCase

  alias SketchpadWeb.UserSocket

  describe "connecting and joining" do

    test "invalid tokens deny connection" do
      assert :error = connect(UserSocket, %{"token" => "invalid"})
    end

    test "valid tokens verify and connect user" do
      valid_token = Phoenix.Token.sign(@endpoint, "user token", "a-user")
      assert {:ok, socket} = connect(UserSocket, %{"token" => valid_token})
      assert socket.assigns.user_id == "a-user"
    end
  end

  describe "after join" do
    setup config do
      {:ok, _return_from_join, socket} =
        socket(nil, %{})
        |> Phoenix.Socket.assign(:user_id, "123")
        |> Phoenix.Socket.assign(:inactive_time, config[:inactive_time])
        |> subscribe_and_join(SketchpadWeb.PadChannel, "pad:lobby", %{})

      {:ok, pid: socket.channel_pid, socket: socket}
    end

    @tag inactive_time: 50
    test "server gracefully shuts down after inactivity", %{pid: pid} do
      Process.unlink(pid)
      Process.monitor(pid)
      assert_receive {:DOWN, _, :process, ^pid, :normal}
    end

    test "presence list is sent on join" do
      assert_push "presence_state", %{}
      assert_broadcast "presence_diff", %{joins: %{"123" => _}}
    end

    test "pushing clear event broadcasts to all peers", %{socket: socket} do
      ref = push socket, "clear", %{}
      assert_reply ref, :ok

      assert_broadcast "clear", %{}
    end
  end
end
