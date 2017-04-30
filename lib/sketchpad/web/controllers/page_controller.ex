defmodule Sketchpad.Web.PageController do
  use Sketchpad.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
