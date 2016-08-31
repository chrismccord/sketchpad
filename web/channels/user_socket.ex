defmodule Sketchpad.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "pad:*", Sketchpad.PadChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket,
    check_origin: ["//127.0.0.1", "//localhost", "//sketchpad.ngrok.io"]
  # transport :longpoll, Phoenix.Transports.LongPoll

  import Phoenix.Token, only: [verify: 4]
  def connect(%{"token" => token}, socket) do
    case verify(socket, "user token", token, max_age: 1209600) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}
      {:error, _invalid} ->
        :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Sketchpad.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
