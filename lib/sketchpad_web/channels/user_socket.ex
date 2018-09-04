defmodule SketchpadWeb.UserSocket do
  use Phoenix.Socket

  ## Channels

  channel "pad:*", SketchpadWeb.PadChannel

  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(socket, "user token", token, max_age: 86400) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, reason} ->
        :error
    end
  end
  def connect(_, socket, _connect_info) do
    :error
  end

  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
